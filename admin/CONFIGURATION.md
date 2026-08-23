# SUN OTA admin gateway configuration

The GitHub Pages entry point remains:

```text
https://techtouchai.github.io/SUN-/admin
```

The only redirect destination is configured in `admin/config.js`:

```js
window.SUN_OTA_ADMIN_URL = "https://your-secure-admin-host/admin";
```

When the secure admin host changes, update `admin/config.js` and commit it to `golden-version`. Do not add a GitHub Token, signing password, or keystore data to this folder; all files are public through GitHub Pages.
