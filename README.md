# luakit-pass

[pass](https://www.passwordstore.org/) password manager plugin for the
[luakit](https://luakit.github.io/) browser, provided as an alternative to the
[formfiller module](https://luakit.github.io/docs/modules/formfiller.html). Uses
[multi-line password data](https://www.passwordstore.org/#organization) for
embedding extra data such as username or email, and is compatible with similar
tools such as [browserpass](https://github.com/dannyvankooten/browserpass) or
[passff](https://github.com/passff/passff).

## Commands and Bindings

- `:pass` will try to auto fill form fields with info from a relevant password
store. Searches for a file matching the current page's domain, or optionally
takes a search term as an argument. Use `:pass!` to auto-submit.
- `:pshow` will display the contents of the password file in the browser.
- `^O` in `insert` mode will insert an OTP code into the currently selected
input field. Requires the [pass-otp](https://github.com/tadfisher/pass-otp)
extension to be installed and configured.
- `^Enter` in a `:pass` menu will instead execute `:pshow`
