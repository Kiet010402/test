-- Arise Crossover - Discord Webhook cho AFKRewards
local allowedPlaceId = 87039211657390 -- PlaceId mà script được phép chạy
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- Khởi tạo Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Sử dụng tên người chơi để tạo file cấu hình riêng cho từng tài khoản
local playerName = Player.Name:gsub("[^%w_]", "_") -- Loại bỏ ký tự đặc biệt
local CONFIG_FILE = "AriseWebhook_" .. playerName .. ".json"

-- Biến kiểm soát trạng thái script
local scriptRunning = true

-- Đọc cấu hình từ file (nếu có)
local function loadConfig()
    local success, result = pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
        return nil
    end)
    
    if success and result then
        print("Đã tải cấu hình từ file cho tài khoản " .. playerName)
        return result
    else
        print("Không tìm thấy file cấu hình cho tài khoản " .. playerName)
        return nil
    end
end

-- Lưu cấu hình xuống file
local function saveConfig(config)
    local success, err = pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(config))
            return true
        end
        return false
    end)
    
    if success then
        print("Đã lưu cấu hình vào file " .. CONFIG_FILE)
        return true
    else
        warn("Lỗi khi lưu cấu hình: " .. tostring(err))
        return false
    end
end

-- Tắt hoàn toàn script (định nghĩa hàm này trước khi được gọi)
local function shutdownScript()
    print("Đang tắt script Arise Webhook...")
    scriptRunning = false
    
    -- Lưu cấu hình trước khi tắt
    saveConfig(CONFIG)
    
    -- Hủy bỏ tất cả các kết nối sự kiện (nếu có)
    for _, connection in pairs(connections or {}) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        end
    end
    
    -- Đóng cửa sổ Rayfield
    Rayfield:Destroy()
    
    print("Script Arise Webhook đã tắt hoàn toàn")
end

-- Cấu hình Webhook Discord của bạn
local WEBHOOK_URL = "YOUR_URL" -- Giá trị mặc định

-- Tải cấu hình từ file (nếu có)
local savedConfig = loadConfig()
if savedConfig then
    if savedConfig.WEBHOOK_URL then
        WEBHOOK_URL = savedConfig.WEBHOOK_URL
        print("Đã tải URL webhook từ cấu hình: " .. WEBHOOK_URL:sub(1, 30) .. "...")
    end
    
    -- Tải tùy chọn AUTO_TELEPORT từ cấu hình nếu có
    local autoTeleportSaved = savedConfig.AUTO_TELEPORT
    if autoTeleportSaved ~= nil then
        print("Đã tải cấu hình AUTO_TELEPORT: " .. tostring(autoTeleportSaved))
    end
end

-- Tùy chọn định cấu hình
local CONFIG = {
    WEBHOOK_URL = WEBHOOK_URL,
    WEBHOOK_COOLDOWN = savedConfig and savedConfig.WEBHOOK_COOLDOWN or 3,
    SHOW_UI = savedConfig and savedConfig.SHOW_UI ~= nil and savedConfig.SHOW_UI or true,
    UI_POSITION = UDim2.new(0.7, 0, 0.05, 0),
    ACCOUNT_NAME = playerName, -- Lưu tên tài khoản vào cấu hình
    AUTO_TELEPORT = savedConfig and savedConfig.AUTO_TELEPORT ~= nil and savedConfig.AUTO_TELEPORT or false, -- Sử dụng giá trị đã lưu
    SELECTED_MAP = savedConfig and savedConfig.SELECTED_MAP or "Map Leveling City" -- Thêm cấu hình cho map đã chọn
}

-- Lưu cấu hình hiện tại
saveConfig(CONFIG)

-- Lưu trữ phần thưởng đã nhận để tránh gửi trùng lặp
local receivedRewards = {}

-- Theo dõi tổng phần thưởng
local totalRewards = {}

-- Lưu trữ số lượng item đã kiểm tra từ RECEIVED
local playerItems = {}

-- Cooldown giữa các lần gửi webhook (giây)
local WEBHOOK_COOLDOWN = CONFIG.WEBHOOK_COOLDOWN
local lastWebhookTime = 0

-- Đang xử lý một phần thưởng (tránh xử lý đồng thời)
local isProcessingReward = false

-- Lưu danh sách các kết nối sự kiện để có thể ngắt kết nối khi tắt script
local connections = {}

-- Tạo khai báo trước các hàm để tránh lỗi gọi nil
local findRewardsUI
local findReceivedFrame
local findNewRewardNotification
local checkNewRewards
local checkReceivedRewards
local readActualItemQuantities
local sendTestWebhook

-- Khởi tạo Window Rayfield
local Window = Rayfield:CreateWindow({
    Name = "Arise Webhook - " .. playerName,
    LoadingTitle = "Arise Crossover",
    LoadingSubtitle = "by DuongTuan",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AriseWebhook",
        FileName = "AriseWebhook_" .. playerName
    },
    KeySystem = false
})

-- Tạo Tab chính
local MainTab = Window:CreateTab("Webhook", 4483362458) -- Sử dụng icon mặc định

-- Tạo Input cho URL Webhook
local WebhookInput = MainTab:CreateInput({
    Name = "Discord Webhook URL",
    PlaceholderText = "Nhập URL webhook Discord...",
    RemoveTextAfterFocusLost = false,
    CurrentValue = CONFIG.WEBHOOK_URL ~= "YOUR_URL" and CONFIG.WEBHOOK_URL or "",
    Flag = "WebhookURL",
    Callback = function(Text)
        if Text ~= "" and Text ~= CONFIG.WEBHOOK_URL then
            CONFIG.WEBHOOK_URL = Text
            WEBHOOK_URL = Text -- Cập nhật biến toàn cục
            
            -- Lưu vào file cấu hình
            if saveConfig(CONFIG) then
                Rayfield:Notify({
                    Title = "Thành công",
                    Content = "Đã lưu URL mới cho " .. playerName,
                    Duration = 3,
                    Image = "check", -- Lucide icon
                })
            else
                Rayfield:Notify({
                    Title = "Lưu ý",
                    Content = "Đã lưu URL mới (không lưu được file)",
                    Duration = 3,
                    Image = "alert-triangle", -- Lucide icon
                })
            end
        end
    end,
})

-- Tạo Slider cho Cooldown
local CooldownSlider = MainTab:CreateSlider({
    Name = "Thời gian cooldown giữa các webhook",
    Range = {1, 10},
    Increment = 1,
    Suffix = "giây",
    CurrentValue = CONFIG.WEBHOOK_COOLDOWN,
    Flag = "WebhookCooldown",
    Callback = function(Value)
        CONFIG.WEBHOOK_COOLDOWN = Value
        WEBHOOK_COOLDOWN = Value
        saveConfig(CONFIG)
    end,
})

-- Tạo nút Test Webhook
local TestButton = MainTab:CreateButton({
    Name = "Kiểm tra kết nối Webhook",
    Callback = function()
        -- Hiển thị thông báo đang kiểm tra
        Rayfield:Notify({
            Title = "Đang kiểm tra",
            Content = "Đang gửi webhook thử nghiệm...",
            Duration = 2,
            Image = "loader", -- Lucide icon
        })
        
        -- Thử gửi webhook kiểm tra
        local success = sendTestWebhook("Kiểm tra kết nối từ Arise Crossover Rewards Tracker")
        
        if success then
            Rayfield:Notify({
                Title = "Thành công",
                Content = "Kiểm tra webhook thành công!",
                Duration = 3,
                Image = "check", -- Lucide icon
            })
        else
            Rayfield:Notify({
                Title = "Lỗi",
                Content = "Kiểm tra webhook thất bại, vui lòng kiểm tra URL!",
                Duration = 5,
                Image = "x", -- Lucide icon
            })
        end
    end,
})

-- Tạo Toggle hiển thị/ẩn UI
local UIToggle = MainTab:CreateToggle({
    Name = "Hiển thị UI",
    CurrentValue = CONFIG.SHOW_UI,
    Flag = "ShowUI",
    Callback = function(Value)
        CONFIG.SHOW_UI = Value
        saveConfig(CONFIG)
    end,
})

-- Tạo Tab thông tin phần thưởng
local RewardsTab = Window:CreateTab("Phần thưởng", "gift") -- Sử dụng icon Lucide

-- Hiển thị thông tin tổng phần thưởng
local RewardsInfo = RewardsTab:CreateSection("Thông tin phần thưởng")

-- Text hiển thị tổng phần thưởng (sẽ được cập nhật)
local TotalRewardsText = ""

-- Tạo một paragraph để hiển thị tổng phần thưởng
local TotalRewardsLabel = RewardsTab:CreateParagraph({
    Title = "Tổng phần thưởng hiện có",
    Content = "Đang tải thông tin phần thưởng..."
})

-- Tạo button để làm mới thông tin phần thưởng
local RefreshButton = RewardsTab:CreateButton({
    Name = "Làm mới thông tin phần thưởng",
    Callback = function()
        -- Đọc số lượng item hiện tại
        readActualItemQuantities()
        
        -- Cập nhật thông tin hiển thị
        local rewardsText = getTotalRewardsText()
        TotalRewardsText = rewardsText
        TotalRewardsLabel:Set({
            Title = "Tổng phần thưởng hiện có", 
            Content = rewardsText
        })
        
        Rayfield:Notify({
            Title = "Đã làm mới",
            Content = "Đã cập nhật thông tin phần thưởng",
            Duration = 2,
            Image = "refresh-cw", -- Lucide icon
        })
    end,
})

-- Tạo button để xóa hết phần thưởng đã lưu
local ClearButton = RewardsTab:CreateButton({
    Name = "Xóa thông tin phần thưởng đã lưu",
    Callback = function()
        -- Xóa hết thông tin phần thưởng đã lưu
        receivedRewards = {}
        totalRewards = {}
        playerItems = {}
        
        -- Cập nhật lại thông tin hiển thị
        TotalRewardsLabel:Set({
            Title = "Tổng phần thưởng hiện có",
            Content = "Đã xóa thông tin phần thưởng"
        })
        
        Rayfield:Notify({
            Title = "Đã xóa",
            Content = "Đã xóa toàn bộ thông tin phần thưởng đã lưu",
            Duration = 3,
            Image = "trash-2", -- Lucide icon
        })
    end,
})

-- Tab cài đặt
local SettingsTab = Window:CreateTab("Cài đặt", "settings") -- Sử dụng icon Lucide

-- Tạo button để tắt script
local ShutdownButton = SettingsTab:CreateButton({
    Name = "Tắt script",
    Callback = function()
        Rayfield:Notify({
            Title = "Xác nhận",
            Content = "Bạn có chắc chắn muốn tắt script?",
            Duration = 5,
            Image = "alert-triangle", -- Lucide icon
            Actions = {
                Ignore = {
                    Name = "Hủy",
                    Callback = function()
                        -- Không làm gì
                    end
                },
                Confirm = {
                    Name = "Tắt",
                    Callback = function()
                        shutdownScript() -- Tắt hoàn toàn script
                    end
                }
            }
        })
    end,
})

-- Tạo Tab Teleport
local TeleportTab = Window:CreateTab("Teleport", "map-pin") -- Sử dụng icon Lucide

-- Debug: Thông báo đã tạo tab
print("Đã tạo tab Teleport")

-- Thêm section để tổ chức UI
local TeleportSection = TeleportTab:CreateSection("Teleport Options")

-- Debug: Thông báo đã tạo section
print("Đã tạo section trong tab Teleport")

-- Tạo Toggle cho Auto Teleport
local AutoTeleportToggle = TeleportTab:CreateToggle({
    Name = "Auto TP to AFK",
    CurrentValue = CONFIG.AUTO_TELEPORT or false,
    Flag = "AutoTeleport",
    Callback = function(Value)
        CONFIG.AUTO_TELEPORT = Value
        saveConfig(CONFIG)
        print("Auto TP to AFK: " .. tostring(Value))
    end,
})

-- Debug: Thông báo đã tạo toggle
print("Đã tạo toggle Auto TP to AFK")

-- Tạo danh sách các map
local mapOptions = {
    "Map Leveling City",
    "Map Grass Village",
    "Map Brum Island", 
    "Map Faceheal Town",
    "Map Lucky Kingdom",
    "Map Nipon City",
    "Map Mori Town"
}

-- Khởi tạo giá trị mặc định
local defaultMap = CONFIG.SELECTED_MAP or "Map Leveling City"
print("Map mặc định: " .. defaultMap)

-- Tạo Dropdown cho lựa chọn map
local MapDropdown = TeleportTab:CreateDropdown({
    Name = "Chọn Map",
    Options = mapOptions,
    CurrentOption = defaultMap,
    Flag = "SelectedMap",
    Callback = function(Option)
        CONFIG.SELECTED_MAP = Option
        saveConfig(CONFIG)
        print("Đã chọn map: " .. Option)
        
        Rayfield:Notify({
            Title = "Đã chọn map",
            Content = "Map đã chọn: " .. Option,
            Duration = 2,
            Image = "check",
        })
    end,
})

-- Debug: Thông báo đã tạo dropdown
print("Đã tạo dropdown chọn map")

-- Tạo button để teleport đến map đã chọn
local TeleportButton = TeleportTab:CreateButton({
    Name = "Teleport đến map đã chọn",
    Callback = function()
        print("Đã nhấn nút teleport")
        teleportToSelectedMap()
    end,
})

-- Debug: Thông báo đã tạo button
print("Đã tạo button teleport")

-- Tạo một danh sách map và đường dẫn (đặt sau khi đã tạo UI)
local mapList = {
    ["Map Leveling City"] = function() return workspace.__World and workspace.__World:FindFirstChild("World 1") end,
    ["Map Grass Village"] = function() return workspace.__World and workspace.__World:FindFirstChild("World 2") end,
    ["Map Brum Island"] = function() return workspace.__World and workspace.__World:FindFirstChild("World 3") end,
    ["Map Faceheal Town"] = function() return workspace.__World and workspace.__World:FindFirstChild("World 4") end,
    ["Map Lucky Kingdom"] = function() return workspace.__World and workspace.__World:FindFirstChild("World 5") end,
    ["Map Nipon City"] = function() return workspace.__World and workspace.__World:FindFirstChild("World 6") end,
    ["Map Mori Town"] = function() return workspace.__World and workspace.__World:FindFirstChild("World 7") end
}

-- Hàm teleport đến map đã chọn 
local function teleportToSelectedMap()
    local selectedMapName = CONFIG.SELECTED_MAP
    print("Bắt đầu teleport đến map: " .. selectedMapName)
    
    -- Lấy hàm để tìm đường dẫn map
    local getMapPath = mapList[selectedMapName]
    
    if not getMapPath then
        print("Không tìm thấy map trong danh sách: " .. selectedMapName)
        Rayfield:Notify({
            Title = "Lỗi",
            Content = "Không tìm thấy thông tin map " .. selectedMapName,
            Duration = 3,
            Image = "alert-triangle",
        })
        return
    end
    
    -- Lấy đường dẫn thực tế của map
    local selectedMapPath = getMapPath()
    print("Đường dẫn map: " .. tostring(selectedMapPath))
    
    if not selectedMapPath then
        print("Thử tìm map bằng phương pháp khác...")
        
        -- Liệt kê cấu trúc workspace
        print("Cấu trúc workspace:")
        for i, child in pairs(workspace:GetChildren()) do
            print(i, child.Name, child.ClassName)
            
            if child.Name == "__World" then
                print("  Cấu trúc __World:")
                for j, worldChild in pairs(child:GetChildren()) do
                    print("  ", j, worldChild.Name, worldChild.ClassName)
                end
            end
        end
        
        -- Phương pháp thay thế 1: Tìm theo số map
        local mapNumber = selectedMapName:match("(%d+)$")
        if mapNumber and workspace.__World and workspace.__World:FindFirstChild("World " .. mapNumber) then
            selectedMapPath = workspace.__World["World " .. mapNumber]
            print("Tìm thấy map theo số: " .. selectedMapPath:GetFullName())
        else
            Rayfield:Notify({
                Title = "Lỗi",
                Content = "Không tìm thấy map " .. selectedMapName,
                Duration = 3, 
                Image = "alert-triangle",
            })
            return
        end
    end
    
    -- Tìm vị trí để teleport
    local mapPosition
    
    -- Liệt kê các phần tử con của map để debug
    print("Các phần tử con của map:")
    for i, child in pairs(selectedMapPath:GetChildren()) do
        print(i, child.Name, child.ClassName)
    end
    
    -- Tìm vị trí từ SpawnLocation
    for _, child in pairs(selectedMapPath:GetDescendants()) do
        if child:IsA("SpawnLocation") then
            mapPosition = child.Position + Vector3.new(0, 5, 0)
            print("Sử dụng vị trí SpawnLocation: " .. child:GetFullName())
            break
        end
    end
    
    -- Tìm vị trí từ BasePart
    if not mapPosition then
        for _, child in pairs(selectedMapPath:GetChildren()) do
            if child:IsA("BasePart") then
                mapPosition = child.Position + Vector3.new(0, 5, 0)
                print("Sử dụng vị trí BasePart: " .. child:GetFullName())
                break
            end
        end
    end
    
    -- Sử dụng vị trí của map nếu không tìm thấy gì khác
    if not mapPosition and selectedMapPath:IsA("BasePart") then
        mapPosition = selectedMapPath.Position + Vector3.new(0, 5, 0)
        print("Sử dụng vị trí của map: " .. selectedMapPath:GetFullName())
    elseif not mapPosition then
        -- Thử lấy vị trí trung tâm của map
        local success, result = pcall(function()
            return selectedMapPath:GetModelCFrame().Position + Vector3.new(0, 5, 0)
        end)
        
        if success then
            mapPosition = result
            print("Sử dụng vị trí trung tâm của map")
        else
            print("Không thể xác định vị trí teleport")
            Rayfield:Notify({
                Title = "Lỗi",
                Content = "Không thể xác định vị trí teleport cho " .. selectedMapName,
                Duration = 3,
                Image = "alert-triangle",
            })
            return
        end
    end
    
    -- Teleport người chơi
    if mapPosition then
        local character = Player.Character or Player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        if humanoidRootPart then
            humanoidRootPart.CFrame = CFrame.new(mapPosition)
            print("Teleport thành công đến: " .. tostring(mapPosition))
            
            Rayfield:Notify({
                Title = "Teleport thành công",
                Content = "Đã teleport đến " .. selectedMapName,
                Duration = 3,
                Image = "check",
            })
        else
            print("Không tìm thấy HumanoidRootPart")
            Rayfield:Notify({
                Title = "Lỗi",
                Content = "Không thể teleport (không tìm thấy HumanoidRootPart)",
                Duration = 3,
                Image = "x",
            })
        end
    end
end

-- Tạo UI cấu hình Webhook (thay thế hàm cũ bằng các phần tử Rayfield)
local function createWebhookUI()
    -- Không cần tạo UI tùy chỉnh nữa vì đã dùng Rayfield
    print("Đã chuyển sang sử dụng Rayfield UI")
    
    -- Đọc số lượng item hiện tại và cập nhật hiển thị
    spawn(function()
        wait(1) -- Chờ UI khởi tạo xong
        readActualItemQuantities()
        local rewardsText = getTotalRewardsText()
        TotalRewardsText = rewardsText
        TotalRewardsLabel:Set({
            Title = "Tổng phần thưởng hiện có", 
            Content = rewardsText
        })
    end)
    
    return nil -- Không cần trả về UI nữa
end

-- Mẫu regex để trích xuất số lượng trong ngoặc
local function extractQuantity(text)
    -- Tìm số lượng trong ngoặc, ví dụ: GEMS(10)
    local quantity = text:match("%((%d+)%)")
    if quantity then
        return tonumber(quantity)
    end
    return nil
end

-- Tạo một ID duy nhất cho phần thưởng mà không dùng timestamp
local function createUniqueRewardId(rewardText)
    -- Loại bỏ khoảng trắng và chuyển về chữ thường để so sánh nhất quán
    local id = rewardText:gsub("%s+", ""):lower()
    
    -- Loại bỏ tiền tố "RECEIVED:" nếu có
    id = id:gsub("received:", "")
    
    -- Loại bỏ tiền tố "YOU GOT A NEW REWARD!" nếu có
    id = id:gsub("yougotanewreward!", "")
    
    return id
end

-- Kiểm tra xem một phần thưởng có phải là CASH không
local function isCashReward(rewardText)
    return rewardText:upper():find("CASH") ~= nil
end

-- Phân tích chuỗi phần thưởng để lấy số lượng và loại
local function parseReward(rewardText)
    -- Loại bỏ các tiền tố không cần thiết
    rewardText = rewardText:gsub("RECEIVED:%s*", "")
    rewardText = rewardText:gsub("YOU GOT A NEW REWARD!%s*", "")
    
    -- Tìm số lượng và loại phần thưởng từ text
    local amount, itemType = rewardText:match("(%d+)%s+([%w%s]+)")
    
    if amount and itemType then
        amount = tonumber(amount)
        itemType = itemType:gsub("^%s+", ""):gsub("%s+$", "") -- Xóa khoảng trắng thừa
        
        -- Kiểm tra xem có số lượng trong ngoặc không
        local quantityInBrackets = itemType:match("%((%d+)%)$")
        if quantityInBrackets then
            -- Loại bỏ phần số lượng trong ngoặc khỏi tên item
            itemType = itemType:gsub("%(%d+%)$", ""):gsub("%s+$", "")
        end
        
        return amount, itemType
    else
        return nil, rewardText
    end
end

-- Tìm UI phần thưởng
findRewardsUI = function()
    -- Tìm trong PlayerGui
    for _, gui in pairs(Player.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            -- Tìm frame chứa các phần thưởng
            local rewardsFrame = gui:FindFirstChild("REWARDS", true) 
            if rewardsFrame then
                return rewardsFrame.Parent
            end
            
            -- Tìm theo tên khác nếu không tìm thấy
            for _, obj in pairs(gui:GetDescendants()) do
                if obj:IsA("TextLabel") and (obj.Text == "REWARDS" or obj.Text:find("REWARD")) then
                    return obj.Parent
                end
            end
        end
    end
    return nil
end

-- Theo dõi phần thưởng "RECEIVED"
findReceivedFrame = function()
    -- Thêm thông báo debug
    print("Đang tìm kiếm UI RECEIVED...")
    
    for _, gui in pairs(Player.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            -- Phương pháp 1: Tìm trực tiếp label RECEIVED
            for _, obj in pairs(gui:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Text == "RECEIVED" then
                    print("Đã tìm thấy label RECEIVED qua TextLabel")
                    return obj.Parent
                end
            end
            
            -- Phương pháp 2: Tìm ImageLabel hoặc Frame có tên là RECEIVED
            local receivedFrame = gui:FindFirstChild("RECEIVED", true)
            if receivedFrame then
                print("Đã tìm thấy RECEIVED qua FindFirstChild")
                return receivedFrame.Parent
            end
            
            -- Phương pháp 3: Tìm các Frame chứa phần thưởng 
            for _, frame in pairs(gui:GetDescendants()) do
                if (frame:IsA("Frame") or frame:IsA("ScrollingFrame")) and
                   (frame.Name:upper():find("RECEIVED") or 
                    (frame.Name:upper():find("REWARD") and not frame.Name:upper():find("REWARDS"))) then
                    print("Đã tìm thấy RECEIVED qua tên Frame: " .. frame.Name)
                    return frame
                end
            end
            
            -- Phương pháp 4: Tìm các phần thưởng đặc trưng trong RECEIVED
            for _, frame in pairs(gui:GetDescendants()) do
                if frame:IsA("Frame") or frame:IsA("ImageLabel") then
                    -- Đếm số lượng item trong frame
                    local itemCount = 0
                    local hasPercentage = false
                    
                    for _, child in pairs(frame:GetDescendants()) do
                        if child:IsA("TextLabel") then
                            -- Kiểm tra phần trăm (dấu hiệu của item)
                            if child.Text:match("^%d+%.?%d*%%$") then
                                hasPercentage = true
                            end
                            
                            -- Kiểm tra "POWDER", "GEMS", "TICKETS" (dấu hiệu của item)
                            if child.Text:find("POWDER") or child.Text:find("GEMS") or child.Text:find("TICKETS") then
                                itemCount = itemCount + 1
                            end
                        end
                    end
                    
                    -- Nếu frame chứa nhiều loại item và có phần trăm, có thể là RECEIVED
                    if itemCount >= 2 and hasPercentage and not frame.Name:upper():find("REWARDS") then
                        print("Đã tìm thấy RECEIVED qua việc phân tích nội dung: " .. frame.Name)
                        return frame
                    end
                end
            end
        end
    end
    
    print("KHÔNG thể tìm thấy UI RECEIVED, tiếp tục tìm với cách khác...")
    
    -- Phương pháp cuối: Tìm một frame bất kỳ chứa TextLabel "POWDER", không thuộc REWARDS
    for _, gui in pairs(Player.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, frame in pairs(gui:GetDescendants()) do
                if (frame:IsA("Frame") or frame:IsA("ImageLabel")) and not frame.Name:upper():find("REWARDS") then
                    for _, child in pairs(frame:GetDescendants()) do
                        if child:IsA("TextLabel") and 
                           (child.Text:find("POWDER") or child.Text:find("GEMS")) and
                           not frame:FindFirstChild("REWARDS", true) then
                            local parentName = frame.Parent and frame.Parent.Name or "unknown"
                            print("Tìm thấy frame có thể là RECEIVED: " .. frame.Name .. " (Parent: " .. parentName .. ")")
                            return frame
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

-- Tìm frame thông báo phần thưởng mới "YOU GOT A NEW REWARD!"
findNewRewardNotification = function()
    for _, gui in pairs(Player.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, obj in pairs(gui:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Text:find("YOU GOT A NEW REWARD") then
                    return obj.Parent
                end
            end
        end
    end
    return nil
end

-- Đọc số lượng item thực tế từ UI RECEIVED
readActualItemQuantities = function()
    local receivedUI = findReceivedFrame()
    if not receivedUI then 
        print("Không tìm thấy UI RECEIVED để đọc số lượng")
        return 
    end
    
    print("Đang đọc phần thưởng từ RECEIVED UI: " .. receivedUI:GetFullName())
    
    -- Reset playerItems để cập nhật lại
    playerItems = {}
    local foundAnyItem = false
    
    -- Debug: In ra tất cả con của receivedUI
    print("Các phần tử con của RECEIVED UI:")
    for i, child in pairs(receivedUI:GetChildren()) do
        print("  " .. i .. ": " .. child.Name .. " [" .. child.ClassName .. "]")
    end
    
    for _, itemFrame in pairs(receivedUI:GetChildren()) do
        if itemFrame:IsA("Frame") or itemFrame:IsA("ImageLabel") then
            local itemType = ""
            local baseQuantity = 0
            local multiplier = 1
            
            -- Debug: In thông tin từng frame
            print("Đang phân tích frame: " .. itemFrame.Name)
            
            -- Tìm tên item và số lượng
            for _, child in pairs(itemFrame:GetDescendants()) do
                if child:IsA("TextLabel") then
                    local text = child.Text
                    print("  TextLabel: '" .. text .. "'")
                    
                    -- Cải thiện: Kiểm tra văn bản chứa TIGER
                    if text:find("TIGER") then
                        itemType = "TIGER"
                        print("    Phát hiện TIGER item")
                        
                        -- Tìm số lượng trong ngoặc - ví dụ: TIGER(1)
                        local foundQuantity = extractQuantity(text)
                        if foundQuantity then
                            multiplier = foundQuantity
                            print("    Số lượng TIGER: " .. multiplier)
                        end
                        
                        -- Nếu không tìm được số lượng, giả định là 1
                        if multiplier <= 0 then
                            multiplier = 1
                        end
                        
                        -- Nếu không có baseQuantity, giả định là 1
                        if baseQuantity <= 0 then
                            baseQuantity = 1
                        end
                    -- Thêm xử lý cho TWIN PRISM BLADES
                    elseif text:find("TWIN PRISM BLADES") then
                        itemType = "TWIN PRISM BLADES"
                        print("    Phát hiện TWIN PRISM BLADES item")
                        
                        -- Tìm số lượng trong ngoặc - ví dụ: TWIN PRISM BLADES(1)
                        local foundQuantity = extractQuantity(text)
                        if foundQuantity then
                            multiplier = foundQuantity
                            print("    Số lượng TWIN PRISM BLADES: " .. multiplier)
                        end
                        
                        -- Nếu không tìm được số lượng, giả định là 1
                        if multiplier <= 0 then
                            multiplier = 1
                        end
                        
                        -- Nếu không có baseQuantity, giả định là 1
                        if baseQuantity <= 0 then
                            baseQuantity = 1
                        end
                    -- Thêm xử lý cho ZIRU G
                    elseif text:find("ZIRU G") then
                        itemType = "ZIRU G"
                        print("    Phát hiện ZIRU G item")
                        
                        -- Tìm số lượng trong ngoặc - ví dụ: ZIRU G(1)
                        local foundQuantity = extractQuantity(text)
                        if foundQuantity then
                            multiplier = foundQuantity
                            print("    Số lượng ZIRU G: " .. multiplier)
                        end
                        
                        -- Nếu không tìm được số lượng, giả định là 1
                        if multiplier <= 0 then
                            multiplier = 1
                        end
                        
                        -- Nếu không có baseQuantity, giả định là 1
                        if baseQuantity <= 0 then
                            baseQuantity = 1
                        end
                    end
                    
                    -- Tìm loại item (GEMS, POWDER, TICKETS, v.v.)
                    local foundItemType = text:match("(%w+)%s*%(%d+%)") or text:match("(%w+)%s*$")
                    if foundItemType then
                        itemType = foundItemType
                        print("    Phát hiện loại item: " .. itemType)
                    end
                    
                    -- Tìm số lượng trong ngoặc - ví dụ: GEMS(1)
                    local foundQuantity = extractQuantity(text)
                    if foundQuantity then
                        multiplier = foundQuantity
                        print("    Phát hiện số lượng từ ngoặc (multiplier): " .. multiplier)
                    end
                    
                    -- Tìm số lượng đứng trước tên item - ví dụ: 500 GEMS
                    local amountPrefix = text:match("^(%d+)%s+%w+")
                    if amountPrefix then
                        baseQuantity = tonumber(amountPrefix)
                        print("    Phát hiện số lượng cơ bản: " .. baseQuantity)
                    end
                end
            end
            
            -- Tính toán số lượng thực tế bằng cách nhân số lượng cơ bản với hệ số từ ngoặc
            local finalQuantity = baseQuantity * multiplier
            print("    Số lượng cuối cùng: " .. baseQuantity .. " x " .. multiplier .. " = " .. finalQuantity)
            
            -- Chỉ lưu các phần thưởng không phải CASH
            if itemType ~= "" and finalQuantity > 0 and not isCashReward(itemType) then
                playerItems[itemType] = (playerItems[itemType] or 0) + finalQuantity
                print("Đã đọc item: " .. finalQuantity .. " " .. itemType .. " (từ " .. baseQuantity .. " x " .. multiplier .. ")")
                foundAnyItem = true
            elseif itemType ~= "" and finalQuantity > 0 then
                print("Bỏ qua item CASH: " .. finalQuantity .. " " .. itemType)
            end
        end
    end
    
    -- Cố gắng đọc theo cách khác nếu không tìm thấy item nào
    if not foundAnyItem then
        print("Không tìm thấy item nào bằng phương pháp thông thường, thử phương pháp thay thế...")
        
        -- Tìm tất cả TextLabel trong receivedUI có chứa GEMS, POWDER, TICKETS, TIGER
        for _, child in pairs(receivedUI:GetDescendants()) do
            if child:IsA("TextLabel") then
                local text = child.Text
                
                -- Tìm item có pattern X ITEM_TYPE(Y) hoặc ITEM_TYPE(Y)
                local baseAmount, itemType, multiplier = text:match("(%d+)%s+([%w%s]+)%((%d+)%)")
                if baseAmount and itemType and multiplier then
                    baseAmount = tonumber(baseAmount)
                    multiplier = tonumber(multiplier)
                    local finalAmount = baseAmount * multiplier
                    
                    if not isCashReward(itemType) then
                        playerItems[itemType] = (playerItems[itemType] or 0) + finalAmount
                        print("Phương pháp thay thế - Đã đọc item: " .. finalAmount .. " " .. itemType .. " (từ " .. baseAmount .. " x " .. multiplier .. ")")
                        foundAnyItem = true
                    end
                else
                    -- Kiểm tra văn bản có chứa TIGER(X), TWIN PRISM BLADES(X) hoặc ZIRU G(X)
                    local itemType, multiplier = text:match("([%w%s]+)%((%d+)%)")
                    if itemType and multiplier then
                        if itemType == "TIGER" or text:find("TIGER") or
                           itemType == "TWIN PRISM BLADES" or text:find("TWIN PRISM BLADES") or
                           itemType == "ZIRU G" or text:find("ZIRU G") then
                            
                            multiplier = tonumber(multiplier)
                            if multiplier and multiplier > 0 and not isCashReward(itemType) then
                                playerItems[itemType] = (playerItems[itemType] or 0) + multiplier
                                print("Phương pháp thay thế - Đã đọc item đặc biệt: " .. multiplier .. " " .. itemType)
                                foundAnyItem = true
                            end
                        end
                    end
                    
                    -- Phương pháp đơn giản hơn: tìm tên item đặc biệt mà không có định dạng
                    if text:find("TWIN PRISM BLADES") and not playerItems["TWIN PRISM BLADES"] then
                        playerItems["TWIN PRISM BLADES"] = (playerItems["TWIN PRISM BLADES"] or 0) + 1
                        print("Phương pháp thay thế - Đã đọc TWIN PRISM BLADES")
                        foundAnyItem = true
                    elseif text:find("ZIRU G") and not playerItems["ZIRU G"] then
                        playerItems["ZIRU G"] = (playerItems["ZIRU G"] or 0) + 1
                        print("Phương pháp thay thế - Đã đọc ZIRU G")
                        foundAnyItem = true
                    end
                end
            end
        end
    end
    
    -- Thêm: Kiểm tra đặc biệt cho TIGER nếu vẫn chưa thấy
    if not playerItems["TIGER"] then
        for _, child in pairs(receivedUI:GetDescendants()) do
            if child:IsA("TextLabel") and child.Text:find("TIGER") then
                print("Phát hiện TIGER thông qua kiểm tra đặc biệt: " .. child.Text)
                -- Tìm số lượng trong ngoặc nếu có
                local quantity = extractQuantity(child.Text) or 1
                playerItems["TIGER"] = (playerItems["TIGER"] or 0) + quantity
                foundAnyItem = true
            end
        end
    end
    
    -- Thêm: Kiểm tra đặc biệt cho TWIN PRISM BLADES nếu vẫn chưa thấy
    if not playerItems["TWIN PRISM BLADES"] then
        for _, child in pairs(receivedUI:GetDescendants()) do
            if child:IsA("TextLabel") and child.Text:find("TWIN PRISM BLADES") then
                print("Phát hiện TWIN PRISM BLADES thông qua kiểm tra đặc biệt: " .. child.Text)
                -- Tìm số lượng trong ngoặc nếu có
                local quantity = extractQuantity(child.Text) or 1
                playerItems["TWIN PRISM BLADES"] = (playerItems["TWIN PRISM BLADES"] or 0) + quantity
                foundAnyItem = true
            end
        end
    end
    
    -- Thêm: Kiểm tra đặc biệt cho ZIRU G nếu vẫn chưa thấy
    if not playerItems["ZIRU G"] then
        for _, child in pairs(receivedUI:GetDescendants()) do
            if child:IsA("TextLabel") and child.Text:find("ZIRU G") then
                print("Phát hiện ZIRU G thông qua kiểm tra đặc biệt: " .. child.Text)
                -- Tìm số lượng trong ngoặc nếu có
                local quantity = extractQuantity(child.Text) or 1
                playerItems["ZIRU G"] = (playerItems["ZIRU G"] or 0) + quantity
                foundAnyItem = true
            end
        end
    end
    
    -- Hiển thị tất cả các item đã đọc được
    print("----- Danh sách item hiện có (không bao gồm CASH) -----")
    if next(playerItems) ~= nil then
        for itemType, amount in pairs(playerItems) do
            print(itemType .. ": " .. amount)
        end
    else
        print("Không đọc được bất kỳ item nào từ UI RECEIVED!")
    end
    print("------------------------------------------------------")
    
    return playerItems
end

-- Cập nhật tổng phần thưởng
local function updateTotalRewards(rewardText)
    local amount, itemType = parseReward(rewardText)
    
    if amount and itemType then
        -- Bỏ qua CASH
        if isCashReward(itemType) then
            print("Bỏ qua cập nhật CASH: " .. amount .. " " .. itemType)
            return
        end
        
        if not totalRewards[itemType] then
            totalRewards[itemType] = amount
        else
            totalRewards[itemType] = totalRewards[itemType] + amount
        end
        print("Đã cập nhật tổng phần thưởng: " .. amount .. " " .. itemType)
    end
end

-- Tạo chuỗi tổng hợp tất cả phần thưởng
local function getTotalRewardsText()
    local result = "Tổng phần thưởng:\n"
    
    -- Đọc số lượng item thực tế từ UI
    readActualItemQuantities()
    
    -- Ưu tiên hiển thị số liệu từ playerItems nếu có
    if next(playerItems) ~= nil then
        for itemType, amount in pairs(playerItems) do
            -- Loại bỏ CASH (thêm biện pháp bảo vệ)
            if not isCashReward(itemType) then
                result = result .. "- " .. amount .. " " .. itemType .. "\n"
            end
        end
    else
        -- Sử dụng totalRewards nếu không đọc được từ UI
        for itemType, amount in pairs(totalRewards) do
            -- Loại bỏ CASH (thêm biện pháp bảo vệ)
            if not isCashReward(itemType) then
                result = result .. "- " .. amount .. " " .. itemType .. "\n"
            end
        end
    end
    
    return result
end

-- Tạo chuỗi hiển thị các phần thưởng vừa nhận
local function getLatestRewardsText(newRewardInfo)
    -- Loại bỏ các tiền tố không cần thiết
    local cleanRewardInfo = newRewardInfo:gsub("RECEIVED:%s*", "")
    cleanRewardInfo = cleanRewardInfo:gsub("YOU GOT A NEW REWARD!%s*", "")
    
    local amount, itemType = parseReward(cleanRewardInfo)
    local result = "Phần thưởng mới:\n- " .. cleanRewardInfo .. "\n\n"
    
    -- Chỉ hiển thị tổng nếu không phải CASH
    if amount and itemType and playerItems[itemType] and not isCashReward(itemType) then
        result = result .. "Tổng " .. itemType .. ": " .. playerItems[itemType] .. " (+" .. amount .. ")\n"
    end
    
    return result
end

-- Kiểm tra xem có thể gửi webhook không (cooldown)
local function canSendWebhook()
    local currentTime = tick()
    if currentTime - lastWebhookTime < WEBHOOK_COOLDOWN then
        return false
    end
    return true
end

-- Gửi webhook thử nghiệm để kiểm tra kết nối
sendTestWebhook = function(customMessage)
    -- Nếu đang xử lý phần thưởng khác, không gửi webhook thử nghiệm
    if isProcessingReward then
        print("Đang xử lý phần thưởng khác, không thể gửi webhook thử nghiệm")
        return false
    end
    
    -- Đánh dấu đang xử lý
    isProcessingReward = true
    
    local message = customMessage or "Đây là webhook thử nghiệm từ Arise Crossover Rewards Tracker"
    
    local data = {
        content = nil,
        embeds = {
            {
                title = "🔍 Arise Crossover - Webhook Thử Nghiệm",
                description = message,
                color = 5814783, -- Màu tím
                fields = {
                    {
                        name = "Thời gian",
                        value = os.date("%d/%m/%Y %H:%M:%S"),
                        inline = true
                    },
                    {
                        name = "Người chơi",
                        value = Player.Name,
                        inline = true
                    }
                },
                footer = {
                    text = "Arise Crossover Rewards Tracker - DuongTuan"
                }
            }
        }
    }
    
    -- Chuyển đổi dữ liệu thành chuỗi JSON
    local jsonData = HttpService:JSONEncode(data)
    
    print("Đang gửi webhook thử nghiệm...")
    
    -- Sử dụng HTTP request từ executor
    local success, err = pcall(function()
        -- Synapse X
        if syn and syn.request then
            syn.request({
                Url = CONFIG.WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
            print("Đã gửi webhook thử nghiệm qua syn.request")
        -- KRNL, Script-Ware và nhiều executor khác
        elseif request then
            request({
                Url = CONFIG.WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
            print("Đã gửi webhook thử nghiệm qua request")
        -- Các Executor khác
        elseif http and http.request then
            http.request({
                Url = CONFIG.WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
            print("Đã gửi webhook thử nghiệm qua http.request")
        -- JJSploit và một số executor khác
        elseif httppost then
            httppost(CONFIG.WEBHOOK_URL, jsonData)
            print("Đã gửi webhook thử nghiệm qua httppost")
        else
            error("Không tìm thấy HTTP API nào được hỗ trợ bởi executor hiện tại")
        end
    end)
    
    -- Kết thúc xử lý
    wait(0.5)
    isProcessingReward = false
    
    if success then
        -- Hiển thị thông báo Rayfield khi gửi thành công
        Rayfield:Notify({
            Title = "Thử nghiệm thành công",
            Content = "Đã gửi webhook thử nghiệm thành công",
            Duration = 3,
            Image = "check", -- Lucide icon
        })
        print("Đã gửi webhook thử nghiệm thành công")
        return true
    else
        -- Hiển thị thông báo Rayfield khi gửi thất bại
        Rayfield:Notify({
            Title = "Thử nghiệm thất bại",
            Content = "Lỗi: " .. tostring(err),
            Duration = 5,
            Image = "x", -- Lucide icon
        })
        warn("Lỗi gửi webhook thử nghiệm: " .. tostring(err))
        return false
    end
end

-- Tìm kiếm các phần tử UI ban đầu
local function findAllUIElements()
    print("Đang tìm kiếm các phần tử UI...")
    local rewardsUI = findRewardsUI()
    local receivedUI = findReceivedFrame()
    local newRewardUI = findNewRewardNotification()
    
    -- Đọc số lượng item hiện tại
    readActualItemQuantities()
    
    -- Kiểm tra thông báo phần thưởng mới trước tiên
    if newRewardUI then
        print("Đã tìm thấy thông báo YOU GOT A NEW REWARD!")
        checkNewRewardNotification(newRewardUI)
    else
        print("Chưa tìm thấy thông báo phần thưởng mới")
        
        -- Nếu không có thông báo NEW REWARD, kiểm tra REWARDS
        if rewardsUI then
            print("Đã tìm thấy UI phần thưởng")
            checkNewRewards(rewardsUI)
        else
            warn("Không tìm thấy UI phần thưởng")
        end
    end
    
    -- Luôn đọc RECEIVED để cập nhật số lượng item hiện tại
    if receivedUI then
        print("Đã tìm thấy UI RECEIVED")
        checkReceivedRewards(receivedUI)
    end
    
    return rewardsUI, receivedUI, newRewardUI
end

-- Theo dõi thay đổi trong PlayerGui
local playerGuiConnection
playerGuiConnection = Player.PlayerGui.ChildAdded:Connect(function(child)
    if not scriptRunning then
        playerGuiConnection:Disconnect()
        return
    end
    
    if child:IsA("ScreenGui") then
        delay(2, function()
            if scriptRunning then
                findAllUIElements()
            end
        end)
    end
end)

-- Theo dõi sự xuất hiện của thông báo phần thưởng mới
spawn(function()
    while scriptRunning and wait(2) do
        if not scriptRunning then break end
        
        local newRewardUI = findNewRewardNotification()
        if newRewardUI then
            checkNewRewardNotification(newRewardUI)
        end
    end
end)

-- Theo dõi phần thưởng mới liên tục (với tần suất thấp hơn)
spawn(function()
    while scriptRunning and wait(5) do
        if not scriptRunning then break end
        
        -- Đọc số lượng item định kỳ
        readActualItemQuantities()
        
        -- Chỉ kiểm tra REWARDS nếu không có NEW REWARD
        local newRewardUI = findNewRewardNotification()
        if not newRewardUI then
            local rewardsUI = findRewardsUI()
            if rewardsUI then
                checkNewRewards(rewardsUI)
            end
        end
        
        -- Luôn kiểm tra RECEIVED để cập nhật số lượng
        local receivedUI = findReceivedFrame()
        if receivedUI then
            checkReceivedRewards(receivedUI)
        end
    end
end)

-- Gửi một webhook về tất cả phần thưởng hiện có trong UI RECEIVED khi khởi động script
local function sendInitialReceivedWebhook()
    print("Đang gửi webhook ban đầu về các phần thưởng hiện có...")
    
    -- Hiển thị thông báo đang gửi webhook ban đầu
    Rayfield:Notify({
        Title = "Khởi tạo",
        Content = "Đang kiểm tra và gửi thông tin phần thưởng hiện có...",
        Duration = 3,
        Image = "loader", -- Lucide icon
    })
    
    -- Tìm UI RECEIVED và đọc dữ liệu
    local receivedUI = findReceivedFrame()
    if not receivedUI then 
        print("Không tìm thấy UI RECEIVED - thử phương án dự phòng...")
        
        -- Hiển thị thông báo không tìm thấy UI
        Rayfield:Notify({
            Title = "Lưu ý",
            Content = "Không tìm thấy UI hiển thị phần thưởng, vui lòng mở UI phần thưởng trong game",
            Duration = 5,
            Image = "alert-triangle", -- Lucide icon
        })
        
        -- Phương án dự phòng sẽ được giữ nguyên
        -- ...
    else
        -- Nếu tìm thấy RECEIVED UI, tiếp tục xử lý
        print("Đã tìm thấy UI RECEIVED, đang đọc dữ liệu...")
        
        -- Tạo danh sách phần thưởng thủ công bằng cách duyệt toàn bộ UI
        local receivedItems = {}
        local foundAny = false
        
        -- Tìm tất cả TextLabel trong RECEIVED UI
        for _, textLabel in pairs(receivedUI:GetDescendants()) do
            if textLabel:IsA("TextLabel") then
                local text = textLabel.Text
                
                -- Nếu chứa GEMS, POWDER hoặc TICKETS
                if (text:find("GEMS") or text:find("POWDER") or text:find("TICKETS")) and not isCashReward(text) then
                    print("Tìm thấy item text: " .. text)
                    table.insert(receivedItems, text)
                    foundAny = true
                end
            end
        end
        
        -- Không gửi webhook nếu không tìm thấy item nào
        if not foundAny then
            print("Không tìm thấy phần thưởng nào trong UI RECEIVED")
            
            -- Hiển thị thông báo không tìm thấy phần thưởng
            Rayfield:Notify({
                Title = "Thông báo",
                Content = "Không tìm thấy phần thưởng nào hiện có",
                Duration = 3,
                Image = "info", -- Lucide icon
            })
            
            -- Vẫn cập nhật lại playerItems để dùng cho lần sau
            readActualItemQuantities()
            return
        end
        
        -- Đánh dấu đang xử lý
        isProcessingReward = true
        
        local allItemsText = ""
        for _, itemText in ipairs(receivedItems) do
            allItemsText = allItemsText .. "- " .. itemText .. "\n"
        end
        
        -- Đọc số lượng item chính xác
        readActualItemQuantities()
        
        -- Hiển thị thông tin từ playerItems thay vì receivedItems
        local itemListText = ""
        if next(playerItems) ~= nil then
            for itemType, amount in pairs(playerItems) do
                itemListText = itemListText .. "- " .. amount .. " " .. itemType .. "\n"
            end
        else
            -- Sử dụng receivedItems nếu không đọc được từ playerItems
            itemListText = allItemsText
        end
        
        local data = {
            content = nil,
            embeds = {
                {
                    title = "🎮 Arise Crossover - Phần thưởng hiện có",
                    description = "Danh sách phần thưởng đã nhận ",
                    color = 7419530, -- Màu xanh biển
                    fields = {
                        {
                            name = "Phần thưởng đã nhận",
                            value = itemListText ~= "" and itemListText or "Không có phần thưởng nào",
                            inline = false
                        },
                        {
                            name = "Thời gian",
                            value = os.date("%d/%m/%Y %H:%M:%S"),
                            inline = true
                        },
                        {
                            name = "Người chơi",
                            value = Player.Name,
                            inline = true
                        }
                    },
                    footer = {
                        text = "Arise Crossover Rewards Tracker - DuongTuan"
                    }
                }
            }
        }
        
        -- Chuyển đổi dữ liệu thành chuỗi JSON
        local jsonData = HttpService:JSONEncode(data)
        
        print("Chuẩn bị gửi webhook với dữ liệu: " .. jsonData:sub(1, 100) .. "...")
        
        -- Sử dụng HTTP request từ executor thay vì HttpService
        local success, err = pcall(function()
            -- Synapse X
            if syn and syn.request then
                syn.request({
                    Url = CONFIG.WEBHOOK_URL,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = jsonData
                })
                print("Đã gửi webhook qua syn.request")
            -- KRNL, Script-Ware và nhiều executor khác
            elseif request then
                request({
                    Url = CONFIG.WEBHOOK_URL,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = jsonData
                })
                print("Đã gửi webhook qua request")
            -- Các Executor khác
            elseif http and http.request then
                http.request({
                    Url = CONFIG.WEBHOOK_URL,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = jsonData
                })
                print("Đã gửi webhook qua http.request")
            -- JJSploit và một số executor khác
            elseif httppost then
                httppost(CONFIG.WEBHOOK_URL, jsonData)
                print("Đã gửi webhook qua httppost")
            else
                error("Không tìm thấy HTTP API nào được hỗ trợ bởi executor hiện tại")
            end
        end)
        
        if success then
            print("Đã gửi webhook ban đầu thành công với " .. #receivedItems .. " phần thưởng")
            
            -- Hiển thị thông báo gửi webhook thành công
            Rayfield:Notify({
                Title = "Thành công",
                Content = "Đã gửi thông tin " .. #receivedItems .. " phần thưởng hiện có",
                Duration = 3,
                Image = "check", -- Lucide icon
            })
        else
            warn("Lỗi gửi webhook ban đầu: " .. tostring(err))
            
            -- Hiển thị thông báo lỗi
            Rayfield:Notify({
                Title = "Lỗi",
                Content = "Không thể gửi webhook ban đầu: " .. tostring(err),
                Duration = 5,
                Image = "x", -- Lucide icon
            })
        end
        
        -- Kết thúc xử lý
        wait(0.5)
        isProcessingReward = false
        lastWebhookTime = tick() -- Cập nhật thời gian gửi webhook cuối cùng
    end
end

-- Khởi tạo tìm kiếm ban đầu và tạo UI
delay(3, function()
    print("Bắt đầu tìm kiếm UI và chuẩn bị gửi webhook khởi động...")
    
    -- Tìm các UI
    findAllUIElements()
    
    -- Gửi webhook ban đầu chỉ một lần
    sendInitialReceivedWebhook()
    
    -- Cập nhật thông tin hiển thị phần thưởng trong Rayfield
    if TotalRewardsLabel then
        local rewardsText = getTotalRewardsText()
        TotalRewardsText = rewardsText
        TotalRewardsLabel:Set({
            Title = "Tổng phần thưởng hiện có", 
            Content = rewardsText
        })
    end
    
    -- Thông báo Rayfield đã khởi động xong
    Rayfield:Notify({
        Title = "Arise Webhook đã sẵn sàng",
        Content = "Đang theo dõi phần thưởng của " .. playerName,
        Duration = 5,
        Image = "check-circle", -- Lucide icon
    })
end)

print("Script theo dõi phần thưởng AFKRewards đã được nâng cấp:")
print("- Giao diện mới sử dụng Rayfield")
print("- Gửi webhook khi khởi động để thông báo các phần thưởng hiện có")
print("- Chỉ gửi MỘT webhook cho mỗi phần thưởng mới")
print("- Không hiển thị và không gửi webhook cho CASH")
print("- Kiểm tra số lượng item thực tế từ RECEIVED")
print("- Hiển thị tổng phần thưởng chính xác trong webhook")
print("- Ping @everyone khi phát hiện ZIRU G lần đầu tiên")
print("- Cấu hình riêng biệt cho từng tài khoản: " .. CONFIG_FILE)
print("- Giám sát phần thưởng mới với cooldown " .. WEBHOOK_COOLDOWN .. " giây")
print("- Hỗ trợ phát hiện đặc biệt cho TIGER, TWIN PRISM BLADES và ZIRU G")

-- Gửi thông tin đến Discord webhook (sử dụng HTTP request từ executor)
local function sendWebhook(rewardInfo, rewardObject, isNewReward)
    -- Loại bỏ các tiền tố không cần thiết
    local cleanRewardInfo = rewardInfo:gsub("RECEIVED:%s*", "")
    cleanRewardInfo = cleanRewardInfo:gsub("YOU GOT A NEW REWARD!%s*", "")
    
    -- Bỏ qua nếu phần thưởng là CASH
    if isCashReward(cleanRewardInfo) then
        print("Bỏ qua gửi webhook cho CASH: " .. cleanRewardInfo)
        return
    end
    
    -- Kiểm tra xem có đang xử lý phần thưởng khác không
    if isProcessingReward then
        print("Đang xử lý phần thưởng khác, bỏ qua...")
        return
    end
    
    -- Kiểm tra cooldown
    if not canSendWebhook() then
        print("Cooldown webhook còn " .. math.floor(WEBHOOK_COOLDOWN - (tick() - lastWebhookTime)) .. " giây, bỏ qua...")
        return
    end
    
    -- Tạo ID duy nhất và kiểm tra trùng lặp
    local rewardId = createUniqueRewardId(cleanRewardInfo)
    if receivedRewards[rewardId] then
        print("Phần thưởng này đã được gửi trước đó: " .. cleanRewardInfo)
        return
    end
    
    -- Đánh dấu đang xử lý
    isProcessingReward = true
    lastWebhookTime = tick()
    
    -- Đánh dấu đã nhận
    receivedRewards[rewardId] = true
    
    -- Đọc số lượng item thực tế trước khi gửi webhook
    readActualItemQuantities()
    
    local title = "🎁 Arise Crossover - AFKRewards"
    local description = "Phần thưởng mới đã nhận được!"
    
    -- Cập nhật tổng phần thưởng
    updateTotalRewards(cleanRewardInfo)

    -- Kiểm tra xem phần thưởng có chứa ZIRU G không để ping @everyone (mỗi lần phát hiện ZIRU G)
    local hasZiruG = cleanRewardInfo:find("ZIRU G") ~= nil
    local shouldPingEveryone = hasZiruG
    
    local data = {
        content = shouldPingEveryone and "@everyone Phát hiện ZIRU G!" or nil,
        embeds = {
            {
                title = title,
                description = description,
                color = 7419530, -- Màu xanh biển
                fields = {
                    {
                        name = "Thông tin phần thưởng",
                        value = getLatestRewardsText(cleanRewardInfo),
                        inline = false
                    },
                    {
                        name = "Thời gian",
                        value = os.date("%d/%m/%Y %H:%M:%S"),
                        inline = true
                    },
                    {
                        name = "Người chơi",
                        value = Player.Name,
                        inline = true
                    },
                    {
                        name = "Tổng hợp phần thưởng",
                        value = getTotalRewardsText(),
                        inline = false
                    }
                },
                footer = {
                    text = "Arise Crossover Rewards Tracker - DuongTuan"
                }
            }
        }
    }
    
    -- Chuyển đổi dữ liệu thành chuỗi JSON
    local jsonData = HttpService:JSONEncode(data)
    
    -- Cập nhật URL từ cấu hình
    local currentWebhookUrl = CONFIG.WEBHOOK_URL
    
    -- Sử dụng HTTP request từ executor thay vì HttpService
    local success, err = pcall(function()
        -- Synapse X
        if syn and syn.request then
            syn.request({
                Url = currentWebhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        -- KRNL, Script-Ware và nhiều executor khác
        elseif request then
            request({
                Url = currentWebhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        -- Các Executor khác
        elseif http and http.request then
            http.request({
                Url = currentWebhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        -- JJSploit và một số executor khác
        elseif httppost then
            httppost(currentWebhookUrl, jsonData)
        else
            error("Không tìm thấy HTTP API nào được hỗ trợ bởi executor hiện tại")
        end
    end)
    
    if success then
        print("Đã gửi phần thưởng thành công: " .. cleanRewardInfo)
        if shouldPingEveryone then
            print("Đã ping @everyone vì phát hiện ZIRU G!")
        end
        
        -- Hiển thị thông báo Rayfield khi nhận phần thưởng
        Rayfield:Notify({
            Title = "Phần thưởng mới!",
            Content = cleanRewardInfo,
            Duration = 5,
            Image = "gift", -- Lucide icon
        })
        
        -- Cập nhật thông tin hiển thị trong UI
        if TotalRewardsLabel then
            local rewardsText = getTotalRewardsText()
            TotalRewardsText = rewardsText
            TotalRewardsLabel:Set({
                Title = "Tổng phần thưởng hiện có", 
                Content = rewardsText
            })
        end
    else
        warn("Lỗi gửi webhook: " .. tostring(err))
        
        -- Hiển thị thông báo lỗi trong Rayfield
        Rayfield:Notify({
            Title = "Lỗi gửi webhook",
            Content = "Không thể gửi thông tin phần thưởng",
            Duration = 5,
            Image = "alert-triangle", -- Lucide icon
        })
    end
    
    -- Kết thúc xử lý
    wait(0.5) -- Chờ một chút để tránh xử lý quá nhanh
    isProcessingReward = false
end

-- Set này dùng để theo dõi đã gửi webhook của phần thưởng
local sentRewards = {}

-- Kiểm tra phần thưởng mới từ thông báo "YOU GOT A NEW REWARD!"
checkNewRewardNotification = function(notificationContainer)
    if not notificationContainer then return end
    
    -- Tìm các thông tin phần thưởng trong thông báo
    local rewardText = ""
    
    for _, child in pairs(notificationContainer:GetDescendants()) do
        if child:IsA("TextLabel") and not child.Text:find("YOU GOT") then
            rewardText = rewardText .. child.Text .. " "
        end
    end
    
    -- Nếu tìm thấy thông tin phần thưởng
    if rewardText ~= "" then
        -- Tạo ID để kiểm tra
        local rewardId = createUniqueRewardId(rewardText)
        
        -- Nếu chưa gửi phần thưởng này
        if not sentRewards[rewardId] then
            sentRewards[rewardId] = true
            
            -- Đọc số lượng item hiện tại trước
            readActualItemQuantities()
            -- Gửi webhook với thông tin phần thưởng mới
            sendWebhook(rewardText, notificationContainer, true)
            return true
        end
    end
    
    return false
end

-- Kiểm tra phần thưởng mới
checkNewRewards = function(rewardsContainer)
    if not rewardsContainer then return end
    
    for _, rewardObject in pairs(rewardsContainer:GetChildren()) do
        if rewardObject:IsA("Frame") or rewardObject:IsA("ImageLabel") then
            -- Tìm các text label trong phần thưởng
            local rewardText = ""
            
            for _, child in pairs(rewardObject:GetDescendants()) do
                if child:IsA("TextLabel") then
                    rewardText = rewardText .. child.Text .. " "
                end
            end
            
            -- Nếu là phần thưởng có dữ liệu
            if rewardText ~= "" then
                -- Tạo ID để kiểm tra
                local rewardId = createUniqueRewardId(rewardText)
                
                -- Nếu chưa gửi phần thưởng này
                if not sentRewards[rewardId] then
                    sentRewards[rewardId] = true
                    sendWebhook(rewardText, rewardObject, false)
                end
            end
        end
    end
end

-- Kiểm tra khi nhận được phần thưởng mới
checkReceivedRewards = function(receivedContainer)
    if not receivedContainer then return end
    
    -- Đọc số lượng item hiện tại
    readActualItemQuantities()
    
    -- Ghi nhận đã kiểm tra RECEIVED
    local receivedMarked = false
    
    for _, rewardObject in pairs(receivedContainer:GetChildren()) do
        if rewardObject:IsA("Frame") or rewardObject:IsA("ImageLabel") then
            local rewardText = ""
            
            for _, child in pairs(rewardObject:GetDescendants()) do
                if child:IsA("TextLabel") then
                    rewardText = rewardText .. child.Text .. " "
                end
            end
            
            -- Nếu là phần thưởng có dữ liệu và chưa ghi nhận RECEIVED
            if rewardText ~= "" and not receivedMarked then
                receivedMarked = true
                
                -- Không gửi webhook từ phần RECEIVED nữa, chỉ ghi nhận đã đọc
                -- Webhook sẽ được gửi từ NEW REWARD hoặc REWARDS
                
                -- Đánh dấu tất cả phần thưởng từ RECEIVED đã được xử lý
                local rewardId = createUniqueRewardId("RECEIVED:" .. rewardText)
                sentRewards[rewardId] = true
            end
        end
    end
    
    -- Cập nhật thông tin hiển thị trong UI nếu có thay đổi
    if TotalRewardsLabel then
        local rewardsText = getTotalRewardsText()
        if rewardsText ~= TotalRewardsText then
            TotalRewardsText = rewardsText
            TotalRewardsLabel:Set({
                Title = "Tổng phần thưởng hiện có", 
                Content = rewardsText
            })
        end
    end
end

-- Chức năng Auto Teleport
local function autoTeleportToAFK()
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local placeId = 116614712661486 
    local player = Players.LocalPlayer

    if not player then
        repeat
            task.wait()
            player = Players.LocalPlayer
        until player
    end

    -- Kiểm tra nếu người chơi đã ở nơi cần đến
    if game.PlaceId == placeId then
        return -- Dừng script ngay lập tức nếu đã ở đúng nơi
    end

    task.wait(30) -- Chờ 30 giây trước khi thực hiện teleport

    local success, errorMessage = pcall(function()
        TeleportService:Teleport(placeId, player)
    end)

    if not success then
        warn("Teleport failed: " .. errorMessage)
    end
end

-- Kiểm tra và thực hiện Auto Teleport nếu được bật
spawn(function()
    while scriptRunning and wait(5) do
        if CONFIG.AUTO_TELEPORT then
            autoTeleportToAFK()
        end
    end
end) 
