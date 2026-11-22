-- Donorcraft account gate using Firebase Authentication REST API.
-- Requires secure.http_mods = donor_accounts in the Luanti server configuration.

local MOD = core.get_current_modname()
local storage = core.get_mod_storage()
local http = core.request_http_api()

local API_KEY = "AIzaSyCf1UO6hrlYXR2GYcgGZUfsbit4Zav1m4E"
local AUTH_BASE = "https://identitytoolkit.googleapis.com/v1"
local authorized = {}
local saved_privs = {}
local busy = {}

local function tr(s)
	return core.formspec_escape(s)
end

local function show_form(player, page, message)
	local name = player:get_player_name()
	local msg = message and ("label[0.5,0.35;" .. tr(message) .. "]") or ""
	local fs
	if page == "register" then
		fs = "formspec_version[6]size[8,7]label[0.5,0.3;Donorcraft — создание аккаунта]" .. msg ..
			"field[0.6,1.7;6.8,0.8;email;Электронная почта;]" ..
			"field[0.6,2.9;6.8,0.8;password;Пароль (не менее 6 символов);]" ..
			"field[0.6,4.1;6.8,0.8;confirm;Повторите пароль;]" ..
			"button[0.6,5.3;3.2,0.8;create;Создать аккаунт]" ..
			"button_exit[4.2,5.3;3.2,0.8;back;Назад]"
	elseif page == "reset" then
		fs = "formspec_version[6]size[8,4.5]label[0.5,0.3;Donorcraft — восстановление пароля]" .. msg ..
			"field[0.6,1.8;6.8,0.8;email;Электронная почта аккаунта;]" ..
			"button[0.6,2.9;3.2,0.8;send;Отправить ссылку]" ..
			"button_exit[4.2,2.9;3.2,0.8;back;Назад]"
	else
		fs = "formspec_version[6]size[8,6]label[0.5,0.3;Donorcraft — вход в аккаунт]" .. msg ..
			"field[0.6,1.7;6.8,0.8;email;Электронная почта;]" ..
			"field[0.6,2.9;6.8,0.8;password;Пароль;]" ..
			"button[0.6,4.1;3.2,0.8;login;Войти]" ..
			"button[4.2,4.1;3.2,0.8;register;Регистрация]" ..
			"button[0.6,5.0;6.8,0.7;reset;Забыли пароль? Восстановить]"
	end
	core.show_formspec(name, MOD .. ":" .. page, fs)
end

local function lock_player(player)
	local name = player:get_player_name()
	if not saved_privs[name] then
		saved_privs[name] = core.get_player_privs(name)
	end
	core.set_player_privs(name, {})
	player:set_physics_override({speed = 0, jump = 0, gravity = 0})
	player:set_velocity({x = 0, y = 0, z = 0})
end

local function unlock_player(player)
	local name = player:get_player_name()
	authorized[name] = true
	if saved_privs[name] then
		core.set_player_privs(name, saved_privs[name])
		saved_privs[name] = nil
	end
	player:set_physics_override({speed = 1, jump = 1, gravity = 1})
	core.chat_send_player(name, "Аккаунт Donorcraft подтверждён. Приятной игры!")
end

local function request_auth(action, payload, callback)
	if not http then
		callback(false, "HTTP API недоступен. Администратору нужно разрешить мод donor_accounts в secure.http_mods.")
		return
	end
	local url = AUTH_BASE .. "/" .. action .. "?key=" .. API_KEY
	http.fetch({
		url = url,
		method = "POST",
		extra_headers = {"Content-Type: application/json"},
		post_data = core.write_json(payload),
		timeout = 15,
	}, function(result)
		local data = result and result.data and core.parse_json(result.data) or nil
		if result and result.succeeded and data and data.idToken then
			callback(true, data)
		elseif result and result.succeeded and data and data.email then
			callback(true, data)
		else
			local err = data and data.error and data.error.message
			callback(false, err or "Не удалось связаться с Firebase. Проверьте подключение и настройки Authentication.")
		end
	end)
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	authorized[name] = nil
	lock_player(player)
	core.after(0.5, function()
		local p = core.get_player_by_name(name)
		if p and not authorized[name] then
			show_form(p, "login", "Войдите или создайте аккаунт Donorcraft.")
		end
	end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	authorized[name] = nil
	saved_privs[name] = nil
	busy[name] = nil
end)

core.register_on_chat_message(function(name)
	if not authorized[name] then
		core.chat_send_player(name, "Сначала войдите в аккаунт Donorcraft.")
		return true
	end
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if not formname:match("^" .. MOD .. ":") then return false end
	local name = player:get_player_name()
	if fields.quit and not authorized[name] then
		core.after(0.1, function()
			local p = core.get_player_by_name(name)
			if p and not authorized[name] then show_form(p, "login", "Вход обязателен для игры.") end
		end)
		return true
	end
	if busy[name] then return true end

	local page = formname:sub(#MOD + 2)
	if fields.register then show_form(player, "register") return true end
	if fields.reset then show_form(player, "reset") return true end
	if fields.back then show_form(player, "login") return true end

	if fields.create then
		local email = (fields.email or ""):trim()
		local password = fields.password or ""
		if #email < 5 or not email:find("@", 1, true) or #password < 6 then
			show_form(player, "register", "Проверьте почту и пароль (минимум 6 символов).")
			return true
		end
		if password ~= (fields.confirm or "") then
			show_form(player, "register", "Пароли не совпадают.")
			return true
		end
		busy[name] = true
		request_auth("accounts:signUp", {email = email, password = password, returnSecureToken = true}, function(ok, result)
			busy[name] = nil
			local p = core.get_player_by_name(name)
			if not p then return end
			if ok then unlock_player(p) else show_form(p, "register", "Ошибка регистрации: " .. tostring(result)) end
		end)
		return true
	end

	if fields.login then
		local email = (fields.email or ""):trim()
		local password = fields.password or ""
		if email == "" or password == "" then show_form(player, "login", "Введите почту и пароль.") return true end
		busy[name] = true
		request_auth("accounts:signInWithPassword", {email = email, password = password, returnSecureToken = true}, function(ok, result)
			busy[name] = nil
			local p = core.get_player_by_name(name)
			if not p then return end
			if ok then unlock_player(p) else show_form(p, "login", "Не удалось войти. Проверьте данные аккаунта.") end
		end)
		return true
	end

	if fields.send then
		local email = (fields.email or ""):trim()
		if email == "" or not email:find("@", 1, true) then show_form(player, "reset", "Введите корректную электронную почту.") return true end
		busy[name] = true
		request_auth("accounts:sendOobCode", {requestType = "PASSWORD_RESET", email = email}, function(ok)
			busy[name] = nil
			local p = core.get_player_by_name(name)
			if not p then return end
			if ok then show_form(p, "login", "Если аккаунт существует, Firebase отправит письмо со ссылкой для сброса пароля.") else show_form(p, "reset", "Не удалось отправить письмо. Проверьте настройки Firebase.") end
		end)
		return true
	end
	return true
end)

core.log("action", "[Donorcraft] Firebase account gate loaded.")
