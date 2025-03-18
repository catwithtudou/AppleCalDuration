-- 主脚本开始
use AppleScript version "2.4" -- 使用 AppleScript 2.4 或更高版本
use scripting additions -- 启用脚本附加功能

-- 配置选项
set enableDetailedLogging to false -- 是否启用详细日志（修改为true开启详细日志）
set timeFormat to "auto" -- 时间格式："minutes"(分钟)、"hours"(小时)或"auto"(自动判断)
set hourThreshold to 300 -- 分钟阈值，超过此值时使用小时单位（当timeFormat为"auto"时生效）

-- 全局变量声明
global logMessages
set logMessages to {}

-- 添加到日志处理程序定义中
on addLog(message)
    global logMessages, enableDetailedLogging
    if enableDetailedLogging then
        set end of logMessages to message
    end if
end addLog

-- 添加到格式化时间显示处理程序中
on formatDuration(durationInMinutes)
    global timeFormat, hourThreshold
    if timeFormat is "minutes" or (timeFormat is "auto" and durationInMinutes ≤ hourThreshold) then
        return durationInMinutes & "min"
    else
        -- 计算小时值(准确值)
        set hoursExact to durationInMinutes / 60

        -- 手动计算一位小数的结果
        set hoursInteger to durationInMinutes div 60
        set minutesRemainder to durationInMinutes mod 60
        set decimalPart to (minutesRemainder / 60 * 10) as integer

        -- 构建最终文本
        if decimalPart = 0 then
            return hoursInteger & ".0h"
        else
            return hoursInteger & "." & decimalPart & "h"
        end if
    end if
end formatDuration

-- 添加到时间信息检查处理程序中
on hasTimeInfo(eventTitle)
    -- 不需要全局变量，所以没有global声明
    if eventTitle contains " [" and eventTitle contains "]" then
        return true
    end if

    if eventTitle contains "min" or eventTitle contains "h" or eventTitle contains "小时" or eventTitle contains "分钟" then
        return true
    end if

    return false
end hasTimeInfo

-- 主程序开始
my addLog("开始执行日历处理脚本")

tell application "Calendar"
    my addLog("连接到日历应用")

    -- 获取所有日历
    set allCalendars to calendars
    my addLog("找到总计 " & (count of allCalendars) & " 个日历")

    -- 创建一个列表用于存储可能的iCloud日历
    set potentialCalendars to {}

    -- 尝试识别可能是iCloud的日历
    repeat with aCalendar in allCalendars
        -- 记录日历名称
        set calName to name of aCalendar
        my addLog("检查日历: " & calName)

        -- 检查日历是否可写入（通常个人iCloud日历是可写入的）
        try
            set isWritable to writable of aCalendar
            my addLog("  - 是否可写入: " & isWritable)

            if isWritable then
                -- 检查是否是订阅日历（通常个人日历不是订阅日历）
                set isSubscribed to false
                try
                    -- 某些版本的Calendar可能支持subscription属性
                    set isSubscribed to (subscription of aCalendar is not missing value)
                on error
                    -- 如果不支持，假设不是订阅日历
                end try

                my addLog("  - 是否是订阅日历: " & isSubscribed)

                if not isSubscribed then
                    -- 检查日历名称是否不是系统预设名称
                    if calName is not "生日" and calName is not "中国节假日" and calName is not "中国大陆节假日" and calName is not "计划的提醒事项" and calName is not "Siri建议" then
                        set end of potentialCalendars to aCalendar
                        my addLog("  - 添加到可能的iCloud日历列表")
                    else
                        my addLog("  - 排除系统预设日历")
                    end if
                else
                    my addLog("  - 排除订阅日历")
                end if
            else
                my addLog("  - 排除不可写入日历")
            end if
        on error errMsg
            my addLog("  - 无法获取日历属性: " & errMsg)
        end try
    end repeat

    -- 报告找到的可能iCloud日历数量
    my addLog("找到 " & (count of potentialCalendars) & " 个可能的iCloud日历")

    -- 设置时间范围(今天)
    set today to current date
    set startOfDay to today - time of today
    set endOfDay to startOfDay + 1 * days
    my addLog("设置时间范围: " & startOfDay & " 到 " & endOfDay)

    -- 处理计数
    set processedCount to 0
    set skippedCount to 0

    -- 遍历所有可能的iCloud日历
    repeat with targetCalendar in potentialCalendars
        -- 获取当前日历名称，用于日志
        set calendarName to name of targetCalendar
        my addLog("处理日历: " & calendarName)

        -- 获取时间范围内的所有事件
        try
            set todayEvents to events of targetCalendar whose start date is greater than or equal to startOfDay and start date is less than endOfDay
            my addLog("  - 找到 " & (count of todayEvents) & " 个符合时间范围的事件")

            -- 遍历所有事件
            repeat with anEvent in todayEvents
                try
                    -- 获取事件标题用于日志
                    set eventTitle to summary of anEvent
                    my addLog("    处理事件: " & eventTitle)

                    -- 检查事件标题是否已包含时间信息
                    if my hasTimeInfo(eventTitle) then
                        my addLog("    - 事件已包含时间信息，跳过")
                        set skippedCount to skippedCount + 1
                    else
                        -- 获取事件开始和结束时间
                        set eventStart to start date of anEvent
                        set eventEnd to end date of anEvent
                        my addLog("    - 时间: " & eventStart & " 到 " & eventEnd)

                        -- 计算事件持续时间(分钟)
                        set durationInMinutes to (eventEnd - eventStart) div 60
                        my addLog("    - 持续时间: " & durationInMinutes & " 分钟")

                        -- 格式化时间信息
                        set formattedDuration to my formatDuration(durationInMinutes)
                        my addLog("    - 格式化时间: " & formattedDuration)

                        -- 获取原事件标题
                        set originalSummary to summary of anEvent

                        -- 更新事件标题，添加时间信息
                        set newSummary to originalSummary & " " & formattedDuration
                        set summary of anEvent to newSummary
                        my addLog("    - 更新标题为: " & newSummary)

                        -- 增加处理计数
                        set processedCount to processedCount + 1
                    end if
                on error errMsg
                    my addLog("    - 处理事件时出错: " & errMsg)
                end try
            end repeat
        on error errMsg
            my addLog("  - 获取事件列表时出错: " & errMsg)
        end try
    end repeat

    my addLog("脚本执行完成，共处理 " & processedCount & " 个事件，跳过 " & skippedCount & " 个已有时间信息的事件")
end tell

-- 将日志保存到桌面文件（如果启用了详细日志）
if enableDetailedLogging and (count of logMessages) > 0 then
    set logText to ""
    repeat with logItem in logMessages
        set logText to logText & logItem & return
    end repeat

    set logFile to (path to desktop folder as string) & "calendar_script_log.txt"
    try
        set fileRef to open for access logFile with write permission
        set eof of fileRef to 0
        write logText to fileRef
        close access fileRef
    on error
        try
            close access logFile
        end try
    end try
end if

-- 显示完成信息
set resultMessage to "已处理可能的iCloud日历下的事件，共更新 " & processedCount & " 个事件的时间信息，跳过 " & skippedCount & " 个已有时间信息的事件。"
if enableDetailedLogging then
    set resultMessage to resultMessage & return & return & "详细日志已保存到桌面。"
end if
display dialog resultMessage