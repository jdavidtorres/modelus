local MainScreenPatch = {}

-- Save the original render method
local originalMainScreenRender = MainScreen.render

-- Override it
MainScreen.render = function(self)
    -- Call the original render so the game draws its background, buttons, and vanilla version text
    originalMainScreenRender(self)

    -- Retrieve the core object to calculate font heights and positions
    local core = getCore()
    local textManager = getTextManager()
    local font = UIFont.Medium

    -- The text we want to draw
    local versionText = "Modelus v0.6.2"

    -- Get dimensions
    local textHeight = textManager:getFontFromEnum(font):getLineHeight()
    local textWidth = textManager:MeasureStringX(font, versionText)

    -- In PZ, the vanilla version is usually drawn at the bottom right.
    -- Vanilla typically uses getCore():getScreenWidth() and screenHeight
    local x = core:getScreenWidth() - textWidth - 10
    
    -- We'll draw our text just above the vanilla version text.
    -- The vanilla game usually leaves some margin at the bottom (like 10-15px) 
    -- and its own height. We offset ours by the font height + a small padding.
    local y = core:getScreenHeight() - textHeight - 25

    -- Draw our string (font, x, y, r, g, b, alpha)
    -- Using a distinct color like a light green or cyan helps it stand out from vanilla
    self:drawTextRight(versionText, x + textWidth, y, 0.4, 0.8, 1.0, 1.0, font)
end

print("[Modelus] MainScreen monkey patched to show Modelus version.")
