local select = require("select_wm")
local lousy = require("lousy")
local ui = ipc_channel("pass.wm")
local filter = lousy.util.table.filter_array

-- browserpass form search logic: https://github.com/dannyvankooten/browserpass/blob/master/chrome/inject.js

local FORM_MARKERS = {
    "login",
    "log-in",
    "log_in",
    "signin",
    "sign-in",
    "sign_in"
}

local USERNAME_FIELDS = {
    selectors = {
        "input[name*=user i]",
        "input[name*=login i]",
        "input[name*=email i]",
        "input[id*=user i]",
        "input[id*=login i]",
        "input[id*=email i]",
        "input[class*=user i]",
        "input[class*=login i]",
        "input[class*=email i]",
        "input[type=email i]",
        "input[type=text i]",
        "input[type=tel i]"
    },
    types = {"email", "text", "tel"}
}

local PASSWORD_FIELDS = {
    selectors = {"input[type=password i]"}
}

local INPUT_FIELDS = {
    selectors = lousy.util.table.join(PASSWORD_FIELDS.selectors, USERNAME_FIELDS.selectors)
}

local SUBMIT_FIELDS = {
    selectors = {
        "[type=submit i]",
        "button[name*=login i]",
        "button[name*=log-in i]",
        "button[name*=log_in i]",
        "button[name*=signin i]",
        "button[name*=sign-in i]",
        "button[name*=sign_in i]",
        "button[id*=login i]",
        "button[id*=log-in i]",
        "button[id*=log_in i]",
        "button[id*=signin i]",
        "button[id*=sign-in i]",
        "button[id*=sign_in i]",
        "button[class*=login i]",
        "button[class*=log-in i]",
        "button[class*=log_in i]",
        "button[class*=signin i]",
        "button[class*=sign-in i]",
        "button[class*=sign_in i]",
        "input[type=button i][name*=login i]",
        "input[type=button i][name*=log-in i]",
        "input[type=button i][name*=log_in i]",
        "input[type=button i][name*=signin i]",
        "input[type=button i][name*=sign-in i]",
        "input[type=button i][name*=sign_in i]",
        "input[type=button i][id*=login i]",
        "input[type=button i][id*=log-in i]",
        "input[type=button i][id*=log_in i]",
        "input[type=button i][id*=signin i]",
        "input[type=button i][id*=sign-in i]",
        "input[type=button i][id*=sign_in i]",
        "input[type=button i][class*=login i]",
        "input[type=button i][class*=log-in i]",
        "input[type=button i][class*=log_in i]",
        "input[type=button i][class*=signin i]",
        "input[type=button i][class*=sign-in i]",
        "input[type=button i][class*=sign_in i]"
    }
}

local function elem_meta(page)
    return page:wrap_js([=[
        return {
            "form_matches": !form || elem.form == form,
            "offset": {
                "width": elem.offsetWidth,
                "height": elem.offsetHeight,
            },
            "bounding_client_rect": elem.getBoundingClientRect(),
            "window_inner": {
                "width": window.innerWidth,
                "height": window.innerHeight,
            },
        };
    ]=], {"elem", "form"})
end

local function elem_focus(page)
    return page:wrap_js([=[
        var eventNames = ["click", "focus"];
        eventNames.forEach(function(eventName) {
          elem.dispatchEvent(new Event(eventName, { bubbles: true }));
        });
    ]=], {"elem"})
end

local function elem_unfocus(page)
    return page:wrap_js([=[
        elem.setAttribute("value", value);
        elem.value = value;
        var eventNames = [
            "keypress",
            "keydown",
            "keyup",
            "input",
            "blur",
            "change"
        ];
        eventNames.forEach(function(eventName) {
            elem.dispatchEvent(new Event(eventName, { bubbles: true }));
        });
    ]=], {"elem"})
end

local function find(page, root, selectors)
    if type(selectors) == "string" then
        selectors = { selectors = selectors }
    end

    local meta = elem_meta(page);
    local matches = {}

    for _, sel in ipairs(selectors.selectors) do
        for _, element in ipairs(root:query(sel)) do
            local matches_ty = true
            if selectors.types ~= nil then
                matches_ty = false
                for _, ty in ipairs(selectors.types) do
                    matches_ty = ty == element.type
                    if matches_ty then
                        break
                    end
                end
            end
            if matches_ty then
                local data = meta(element)

                if data.offset.width < 30 or data.offset.height < 10 then
                    matches_ty = false
                end

                local style = element.style
                if style.visibility == "hidden" or style.display == "none" then
                    matches_ty = false
                end

                if data.bounding_client_rect.x + data.bounding_client_rect.width < 0 or
                    data.bounding_client_rect.y + data.bounding_client_rect.height < 0 or
                    data.bounding_client_rect.x > data.window_inner.width or
                    data.bounding_client_rect.y > data.window_inner.height then
                    matches_ty = false
                end
            end

            if matches_ty then
                table.insert(matches, element)
            end
        end
    end

    return matches
end

ui:add_signal("fill", function (_, page, data)
    local root = page.document.body
    local focus = elem_focus(page)
    local unfocus = elem_unfocus(page)
    local username_field = find(page, root, USERNAME_FIELDS)
    if #username_field > 0 then
        focus(username_field[1])
        username_field = find(page, root, USERNAME_FIELDS)
    end
    if #username_field > 0 then
        username_field[1].value = data.username
        unfocus(username_field[1])
    end

    local password_field = find(page, root, PASSWORD_FIELDS)
    if #password_field > 0 then
        focus(password_field[1])
        password_field = find(page, root, PASSWORD_FIELDS)
    end
    if #password_field > 0 then
        password_field[1].value = data.password
        unfocus(password_field[1])
    end

    if #password_field > 1 then
        msg.warn("still more to fill, otp code maybe?")
        focus(password_field[2])
    elseif #password_field == 1 then
        focus(password_field[1])
    elseif #username_field > 0 then
        focus(username_field[1])
    end

    local submit = find(page, root, SUBMIT_FIELDS)
    if #submit > 0 then
        if data.submit then
            focus(submit[1])
        end
    end
end)

ui:add_signal("fill_otp", function (_, page, data)
    local fn = page:wrap_js([=[
        document.activeElement.value = value;
    ]=], {"value"})
    fn(data.otp)
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
