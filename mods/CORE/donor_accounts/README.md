# Donorcraft accounts (Firebase Authentication)

This mod adds email/password registration, sign-in, and password-reset email.

## Firebase setup

1. In Firebase Console, open **Authentication → Sign-in method**.
2. Enable **Email/Password**.
3. In Authentication settings, ensure the password-reset email template is configured.
4. Realtime Database and Analytics are not used by this account module.

## Luanti server setup

1. Put this game mod in the Donorcraft CORE modpack (it is included in this repository).
2. In the Luanti server's trusted mod HTTP settings, allow this mod:
   `secure.http_mods = donor_accounts`
   The setting belongs in the server's Luanti configuration, not in a world file.
3. Restart the server and inspect the log for `Firebase account gate loaded`.

## Important behavior and limitations

- The Firebase login screen appears after the player has connected to the Luanti server. Luanti's own username/password authentication still happens first; Firebase is an additional Donorcraft account gate, not a replacement for Luanti's server login.
- Passwords are sent directly to Firebase Authentication over HTTPS and are not stored by this mod.
- Firebase ID tokens are not persisted. Players sign in again after reconnecting.
- This mod does not create cloud profiles, cloud saves, achievements, or cloud settings.
- This is an initial integration and must be tested on a private server before public use. The server administrator must configure secure HTTP permissions and Firebase Authentication.
