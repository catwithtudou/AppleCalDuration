-- 主脚本开始
use AppleScript version "2.4" -- 使用 AppleScript 2.4 或更高版本
use scripting additions -- 启用脚本附加功能

-- 全局变量声明
global logMessages
set logMessages to {}

-- 日志处理程序定义
on addLog(message)
	global logMessages
	set end of logMessages to message
end addLog

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
	set startOfDay to today - (time of today)
	set endOfDay to startOfDay + 1 * days
	my addLog("设置时间范围: " & startOfDay & " 到 " & endOfDay)

	-- 处理计数
	set processedCount to 0

	-- 遍历所有可能的iCloud日历
	repeat with targetCalendar in potentialCalendars
		-- 获取当前日历名称，用于日志
		set calendarName to name of targetCalendar
		my addLog("处理日历: " & calendarName)

		-- 获取时间范围内的所有事件
		try
			set todayEvents to (events of targetCalendar whose start date is greater than or equal to startOfDay and start date is less than endOfDay)
			my addLog("  - 找到 " & (count of todayEvents) & " 个符合时间范围的事件")

			-- 遍历所有事件
			repeat with anEvent in todayEvents
				try
					-- 获取事件标题用于日志
					set eventTitle to summary of anEvent
					my addLog("    处理事件: " & eventTitle)

					-- 获取事件开始和结束时间
					set eventStart to start date of anEvent
					set eventEnd to end date of anEvent
					my addLog("    - 时间: " & eventStart & " 到 " & eventEnd)

					-- 计算事件持续时间(分钟)
					set durationInMinutes to (eventEnd - eventStart) div 60
					my addLog("    - 持续时间: " & durationInMinutes & " 分钟")

					-- 获取原事件标题
					set originalSummary to summary of anEvent

					-- 提取不包含时间信息的原始标题（如果已经有时间信息）
					if originalSummary contains " [" then
						set textBeforeBracket to text 1 thru ((offset of " [" in originalSummary) - 1) of originalSummary
						set originalSummary to textBeforeBracket
						my addLog("    - 移除已有时间标记")
					end if

					-- 更新事件标题，添加时间信息
					set newSummary to originalSummary & " [" & durationInMinutes & "分钟]"
					set summary of anEvent to newSummary
					my addLog("    - 更新标题为: " & newSummary)

					-- 增加处理计数
					set processedCount to processedCount + 1
				on error errMsg
					my addLog("    - 处理事件时出错: " & errMsg)
				end try
			end repeat
		on error errMsg
			my addLog("  - 获取事件列表时出错: " & errMsg)
		end try
	end repeat

	my addLog("脚本执行完成，共处理 " & processedCount & " 个事件")
end tell

-- 将日志保存到桌面文件
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

-- 显示完成信息
display dialog "已处理可能的iCloud日历下的事件，共更新 " & processedCount & " 个事件的时间信息。" & return & return & "详细日志已保存到桌面。"