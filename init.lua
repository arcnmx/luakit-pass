local _M = {}

local modes = require "modes"
local binds = require "binds"
local lousy = require "lousy"
local formfiller = require "formfiller"
local pass_wm = require_web_module("pass.wm")

_M.executable = "/usr/bin/pass"
_M.password_store = os.getenv("PASSWORD_STORE_DIR") or (os.getenv("HOME") .. "/.password-store")

_M.MODE_SHOW = "show"
_M.MODE_SUBMIT = "submit"
_M.MODE_FILL = "fill"
_M.MODE_OTP = "otp"

formfiller.extend({
    pass = function (name, field)
        local data = _M.pass_show(name)
        if data ~= nil then
            if field ~= nil then
                return _M.parse_password(data)
            else
                return _M.parse_field(data, field)
            end
        else
            return nil
        end
    end,
    otp = function (name, field)
        return _M.pass_otp(name)
    end,
})

function _M.pass_show(name)
    local f = io.popen(string.format("%s show %q", _M.executable, name))
    local ret = f:read("*all")
    f:close()
    if #ret == 0 then
        return nil
    else
        return ret
    end
end

function _M.pass_otp(name)
    local f = io.popen(string.format("%s otp %q", _M.executable, name))
    local ret = f:read("*line")
    f:close()
    if #ret == 0 then
        return nil
    else
        return ret
    end
end

function _M.parse_lines(pass_data)
    return string.gmatch(pass_data, "[^\n]*")
end

function _M.parse_password(pass_data)
    for line in _M.parse_lines(pass_data) do
        return line
    end

    return nil
end

local username_fields = { "username", "user", "email" }
local otp_field = "otpauth"

function _M.parse_username(pass_data)
    return _M.parse_field(pass_data, username_fields)
end

function _M.parse_field(pass_data, fields)
    if type(fields) == "string" then
        fields = { fields }
    end

    for line in _M.parse_lines(pass_data) do
        for _, field in ipairs(fields) do
            local len = string.len(field)
            if string.sub(line, 1, len) == field and string.sub(line, len + 1, len + 1) == ":" then
                return string.gsub(string.sub(line, len + 2), "^ *", "")
            end
        end
    end

    return nil
end

function _M.has_otp(pass_data)
    return _M.parse_field(pass_data, otp_field) ~= nil
end

function _M.fill(w, name, submit)
    local data = _M.pass_show(name)
    if data ~= nil then
        pass_wm:emit_signal(w.view, "fill", {
            name = name,
            data = data,
            username = _M.parse_username(data),
            password = _M.parse_password(data),
            has_otp = _M.has_otp(data),
            submit = submit or false,
        })
        w:set_mode("insert")
    else
        w:error(string.format("Failed to read %s", name))
    end
end

function _M.fill_otp(w, name)
    local data = _M.pass_otp(name)
    if data ~= nil then
        pass_wm:emit_signal(w.view, "fill_otp", {
            name = name,
            otp = data,
        })
        w:set_mode("insert")
    else
        w:error(string.format("OTP %s failed or missing", name))
    end
end

function _M.show(w, name)
    local data = _M.pass_show(name)
    local otp = nil
    if _M.has_otp(data) then
        otp = _M.pass_otp(name)
    end

    if otp ~= nil then
        data = string.format("[%s] [OTP %s]\n%s", name, otp, data)
    else
        data = string.format("[%s]\n%s", name, data)
    end

    w:notify(data)
end

function _M.query_uri(uri)
    return _M.query(lousy.uri.domains_from_uri(uri))
end

function _M.query(patterns)
    if type(patterns) == "string" then
        patterns = { patterns }
    elseif type(patterns) == nil then
        patterns = {}
    end

    local query = "-iname '*.gpg'"
    if #patterns > 0 then
        query = "-false"
        for _, pattern in ipairs(patterns) do
            query = query .. string.format(" -or -ipath %q -or -ipath %q", "*/" .. pattern .. ".gpg", "*/" .. pattern .. "/*.gpg")
        end
    end

    local ret = {}
    local cmd = string.format("find %q -mindepth 1 -not \\( -name '.*' -prune \\) -and \\( %s \\)", _M.password_store, query)
    local f = io.popen(cmd)
    for line in f:lines() do
        local pass = string.sub(string.gsub(line, "%.gpg$", ""), #_M.password_store + 2)
        table.insert(ret, pass)
    end
    f:close()
    return ret
end

function _M.build_menu(w, arg, mode)
    local menu = {}
    if arg == nil then
        for _, name in ipairs(_M.query_uri(w.view.uri)) do
            table.insert(menu, { name, name = name, mode = mode })
        end
    else
        for _, name in ipairs(_M.query("*" .. arg .. "*")) do
            table.insert(menu, { name, name = name, mode = mode })
        end
    end

    if #menu > 1 then
        w:set_mode("pass-menu", menu)
    elseif #menu == 1 then
        if mode == _M.MODE_SHOW then
            _M.show(w, menu[1].name)
        elseif mode == _M.MODE_FILL then
            _M.fill(w, menu[1].name, false)
        elseif mode == _M.MODE_SUBMIT then
            _M.fill(w, menu[1].name, true)
        elseif mode == _M.MODE_OTP then
            _M.fill_otp(w, menu[1].name)
        end
    else
        w:error("no related passwords found")
    end
end

modes.new_mode("pass-menu", {
    enter = function (w, menu)
        local rows = { { "Pass", title = true } }
        for _, m in ipairs(menu) do
            table.insert(rows, m)
        end
        w.menu:build(rows)
    end,
    leave = function (w)
        w.menu:hide()
    end,
})

modes.add_binds("pass-menu", lousy.util.table.join({
    { "<Return>", "Select pass profile.", function (w)
        local row = w.menu:get()
        w:set_mode()
        if row.mode == _M.MODE_SHOW then
            _M.show(w, row.name)
        elseif row.mode == _M.MODE_FILL then
            _M.fill(w, row.name, false)
        elseif row.mode == _M.MODE_SUBMIT then
            _M.fill(w, row.name, true)
        elseif row.mode == _M.MODE_OTP then
            _M.fill_otp(w, row.name)
        end
    end },
    { "<Control-Return>", "Show pass profile.", function (w)
        local row = w.menu:get()
        if row.mode ~= nil then
            _M.show(w, row.name)
        end
    end },
    { "<Control-j>", "Select next pass profile.", function (w) w.menu:move_down() end },
    { "<Control-k>", "Select previous pass profile.", function (w) w.menu:move_up() end },
    { ":", "Enter `command` mode", function (w) w:set_mode("command") end },
}, binds.menu_binds))

modes.add_binds("insert", {
    { "<Control-o>", "Insert OTP code into currently focused input", function (w)
        _M.build_menu(w, nil, _M.MODE_OTP)
    end },
})

modes.add_cmds({
    { ":p[ass]", "Fill password form.", function (w, o)
        local mode
        if o.bang then
            mode = _M.MODE_SUBMIT
        else
            mode = _M.MODE_FILL
        end
        _M.build_menu(w, o.arg, mode)
    end },
    { ":ps[how]", "Show password.", function (w, o)
        _M.build_menu(w, o.arg, _M.MODE_SHOW)
    end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
