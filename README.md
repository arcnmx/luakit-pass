# luakit-pass

[pass](https://www.passwordstore.org/) password manager plugin for the
[luakit](https://luakit.github.io/) browser.

## Commands and Bindings

- `:pass` will try to auto fill form fields with info from a relevant password
store. Searches for a file matching the current page's domain, or optionally
takes a search term as an argument.
- `:pshow` will display the contents of the password file in the browser.
- `^O` in `insert` mode will insert an OTP code into the currently selected
input field. Requires the [pass-otp](https://github.com/tadfisher/pass-otp)
extension to be installed.
- `^Enter` in a `:pass` menu will instead execute `:pshow`

## Future Improvements

- Tab completion (requires a bit of a completion module rewrite)
- Auto-submit
- Restrict filling to login forms
- Lua implementation of OTP
- `pass generate`
