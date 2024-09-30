function GetDiscordIdentifier(src)
    local identifiers = GetNumPlayerIdentifiers(src)
    for i = 0, identifiers - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if identifier ~= nil and string.match(identifier, "discord") then
            return string.sub(identifier, 9)
        end
    end
    return nil
end

function sendToDiscord(webhook, title, description, color, playerId, societyName)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local discordId = GetDiscordIdentifier(playerId)
    local playerName = GetPlayerName(playerId)

    local embeds = {
        {
            ["title"] = title,
            ["description"] = description,
            ["color"] = color,
            ["footer"] = {
                ["text"] = "Society Logs",
            },
            ["fields"] = {
                {
                    ["name"] = "Player:",
                    ["value"] = playerName .. " <@" .. (discordId or "N/A") .. ">",
                    ["inline"] = true
                },
                {
                    ["name"] = "Society:",
                    ["value"] = societyName,
                    ["inline"] = true
                },
                {
                    ["name"] = "Identifier:",
                    ["value"] = xPlayer.identifier,
                    ["inline"] = true
                }
            }
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({username = "Society Logs", embeds = embeds}), { ['Content-Type'] = 'application/json' })
end


local Jobs = setmetatable({}, {__index = function(_, key)
	return ESX.GetJobs()[key]
end
})
local RegisteredSocieties = {}
local SocietiesByName = {}

function GetSociety(name)
    local society = SocietiesByName[name]
    if not society then
        print(('[^1ERROR^7] Society "%s" does not exist!'):format(name))
    end
    return society
end


exports("GetSociety", GetSociety)

function registerSociety(name, label, account, datastore, inventory, data)
	if SocietiesByName[name] then
		print(('[^3WARNING^7] society already registered, name: ^5%s^7'):format(name))
		return
	end

	local society = {
		name = name,
		label = label,
		account = account,
		datastore = datastore,
		inventory = inventory,
		data = data
	}

	SocietiesByName[name] = society
	table.insert(RegisteredSocieties, society)
end
AddEventHandler('esx_society:registerSociety', registerSociety)
exports("registerSociety", registerSociety)

AddEventHandler('esx_society:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('esx_society:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

RegisterServerEvent('esx_society:checkSocietyBalance')
AddEventHandler('esx_society:checkSocietyBalance', function(society)
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(society)

	if xPlayer.job.name ~= society.name then
		print(('esx_society: %s attempted to call checkSocietyBalance!'):format(xPlayer.identifier))
		return
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		TriggerClientEvent("esx:showNotification", xPlayer.source, TranslateCap('check_balance', ESX.Math.GroupDigits(account.money)))
	end)
end)

AddEventHandler('esx_society:withdrawMoney', function(societyName, amount)
    local source = source
    local society = GetSociety(societyName)
    if not society then
        print(('[^3WARNING^7] Player ^5%s^7 attempted to withdraw from non-existing society - ^5%s^7!'):format(source, societyName))
        return
    end
    local xPlayer = ESX.GetPlayerFromId(source)
    amount = ESX.Math.Round(tonumber(amount))

    if xPlayer.job.name ~= society.name then
        return print(('[^3WARNING^7] Player ^5%s^7 attempted to withdraw from society - ^5%s^7!'):format(source, society.name))
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
        if amount > 0 and account.money >= amount then
            account.removeMoney(amount)
            xPlayer.addMoney(amount, TranslateCap('money_add_reason'))
            Config.NotificationServer(nil, TranslateCap('have_withdrawn', ESX.Math.GroupDigits(amount)), 'success', xPlayer.source)

            sendToDiscord(Config.Webhook, "Money Withdrawal", "Player withdrew " .. amount .. "$ from the society account.", 16711680, source, societyName)
        else
            Config.NotificationServer(nil, TranslateCap('invalid_amount'), 'error', xPlayer.source)
        end
    end)
end)

AddEventHandler('esx_society:depositMoney', function(societyName, amount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local society = GetSociety(societyName)
    if not society then
        print(('[^3WARNING^7] Player ^5%s^7 attempted to deposit to non-existing society - ^5%s^7!'):format(source, societyName))
        return
    end
    amount = ESX.Math.Round(tonumber(amount))

    if xPlayer.job.name ~= society.name then
        return print(('[^3WARNING^7] Player ^5%s^7 attempted to deposit to society - ^5%s^7!'):format(source, society.name))
    end
    if amount > 0 and xPlayer.getMoney() >= amount then
        TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
            xPlayer.removeMoney(amount, TranslateCap('money_remove_reason'))
            account.addMoney(amount)
            Config.NotificationServer('Deposit Successful', TranslateCap('have_deposited', ESX.Math.GroupDigits(amount)), 'success', xPlayer.source)

            sendToDiscord(Config.Webhook, "Money Deposit", "Player deposited " .. amount .. "$ into the society account.", 65280, source, societyName)
        end)
    else
        Config.NotificationServer('Error', TranslateCap('invalid_amount'), 'error', xPlayer.source)
    end
end)

AddEventHandler('esx_society:washMoney', function(society, amount)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local account = xPlayer.getAccount('black_money')
    amount = ESX.Math.Round(tonumber(amount))

    if xPlayer.job.name ~= society then
        return print(('[^3WARNING^7] Player ^5%s^7 attempted to wash money in society - ^5%s^7!'):format(source, society))
    end
    if amount and amount > 0 and account.money >= amount then
        xPlayer.removeAccountMoney('black_money', amount, "Washing")

        MySQL.insert('INSERT INTO society_moneywash (identifier, society, amount) VALUES (?, ?, ?)', {xPlayer.identifier, society, amount}, function(rowsChanged)
            Config.NotificationServer('Money Laundering', TranslateCap('you_have', ESX.Math.GroupDigits(amount)), 'success', xPlayer.source)

            sendToDiscord(Config.Webhook, "Money Laundering", "Player laundered " .. amount .. "$ of dirty money.", 16753920, source, society)
        end)
    else
        Config.NotificationServer('Error', TranslateCap('invalid_amount'), 'error', xPlayer.source)
    end
end)


RegisterServerEvent('esx_society:putVehicleInGarage')
AddEventHandler('esx_society:putVehicleInGarage', function(societyName, vehicle)
	local source = source
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to put vehicle in non-existing society garage - ^5%s^7!'):format(source, societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('esx_society:removeVehicleFromGarage')
AddEventHandler('esx_society:removeVehicleFromGarage', function(societyName, vehicle)
	local source = source
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to remove vehicle from non-existing society garage - ^5%s^7!'):format(source, societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		for i=1, #garage, 1 do
			if garage[i].plate == vehicle.plate then
				table.remove(garage, i)
				break
			end
		end

		store.set('garage', garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:getSocietyMoney', function(source, cb, societyName)
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to get money from non-existing society - ^5%s^7!'):format(source, societyName))
		return cb(0)
	end
	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		cb(account.money or 0)
	end)
end)

ESX.RegisterServerCallback('esx_society:getEmployees', function(source, cb, society)
	local employees = {}

	local xPlayers = ESX.GetExtendedPlayers('job', society)
	for i=1, #(xPlayers) do 
		local xPlayer = xPlayers[i]

		local name = xPlayer.name
		if Config.EnableESXIdentity and name == GetPlayerName(xPlayer.source) then
			name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
		end

		table.insert(employees, {
			name = name,
			identifier = xPlayer.identifier,
			job = {
				name = society,
				label = xPlayer.job.label,
				grade = xPlayer.job.grade,
				grade_name = xPlayer.job.grade_name,
				grade_label = xPlayer.job.grade_label
			}
		})
	end
		
	local query = "SELECT identifier, job_grade FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"

	if Config.EnableESXIdentity then
		query = "SELECT identifier, job_grade, firstname, lastname FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"
	end

	MySQL.query(query, {society},
	function(result)
		for k, row in pairs(result) do
			local alreadyInTable
			local identifier = row.identifier

			for k, v in pairs(employees) do
				if v.identifier == identifier then
					alreadyInTable = true
				end
			end

			if not alreadyInTable then
				local name = TranslateCap('name_not_found')

				if Config.EnableESXIdentity then
					name = row.firstname .. ' ' .. row.lastname 
				end
				
				table.insert(employees, {
					name = name,
					identifier = identifier,
					job = {
						name = society,
						label = Jobs[society].label,
						grade = row.job_grade,
						grade_name = Jobs[society].grades[tostring(row.job_grade)].name,
						grade_label = Jobs[society].grades[tostring(row.job_grade)].label
					}
				})
			end
		end

		cb(employees)
	end)

end)

ESX.RegisterServerCallback('esx_society:getJob', function(source, cb, society)
	if not Jobs[society] then
		return cb(false)
	end

	local job = json.decode(json.encode(Jobs[society]))
	local grades = {}

	for k,v in pairs(job.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	job.grades = grades

	cb(job)
end)

ESX.RegisterServerCallback('esx_society:setJob', function(source, cb, identifier, job, grade, actionType)
    local xPlayer = ESX.GetPlayerFromId(source)
    local isBoss = Config.BossGrades[xPlayer.job.grade_name]
    local xTarget = ESX.GetPlayerFromIdentifier(identifier)

    if not isBoss then
        print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob for Player ^5%s^7!'):format(source, xTarget and xTarget.source or 'N/A'))
        return cb()
    end

    if not xTarget then
        MySQL.update('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {job, grade, identifier}, function()
            cb()
        end)
        return
    end

    local previousJobLabel = xTarget.getJob().label
    local previousJobGrade = xTarget.getJob().grade_label

    xTarget.setJob(job, grade)

    local newJobLabel = xTarget.getJob().label
    local newJobGrade = xTarget.getJob().grade_label

    if actionType == 'hire' then
        Config.NotificationServer(nil, TranslateCap('you_have_been_hired', job), 'success', xTarget.source)
        Config.NotificationServer(nil, TranslateCap('you_have_hired', xTarget.getName()), 'success', xPlayer.source)

        sendToDiscord(Config.Webhook, "Hiring", 
            "Player **" .. xPlayer.getName() .. "** hired " .. xTarget.getName() .. " to the society " .. job .. ".", 
            3066993, source, job)

    elseif actionType == 'promote' then
        Config.NotificationServer(nil, TranslateCap('you_have_been_promoted'), 'success', xTarget.source)
        Config.NotificationServer(nil, TranslateCap('you_have_promoted', xTarget.getName(), newJobLabel), 'success', xPlayer.source)

        sendToDiscord(Config.Webhook, "Promotion", 
            "Player **" .. xPlayer.getName() .. "** promoted " .. xTarget.getName() .. " in society " .. job .. ".\n" ..
            "**Previous rank:** " .. previousJobGrade .. "\n**New rank:** " .. newJobGrade, 
            3447003, source, job)

    elseif actionType == 'fire' then
        Config.NotificationServer(nil, TranslateCap('you_have_been_fired', previousJobLabel), 'error', xTarget.source)
        Config.NotificationServer(nil, TranslateCap('you_have_fired', xTarget.getName()), 'error', xPlayer.source)

        sendToDiscord(Config.Webhook, "Firing", 
            "Player **" .. xPlayer.getName() .. "** fired " .. xTarget.getName() .. " from the society " .. previousJobLabel .. ".\n" ..
            "**Previous rank:** " .. previousJobGrade, 
            15158332, source, job)
    end

    cb()
end)





ESX.RegisterServerCallback('esx_society:setJobSalary', function(source, cb, job, grade, salary)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == job and Config.BossGrades[xPlayer.job.grade_name] then
		if salary <= Config.MaxSalary then
			MySQL.update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', {salary, job, grade},
			function(rowsChanged)
				Jobs[job].grades[tostring(grade)].salary = salary
				ESX.RefreshJobs()
				Wait(1)
				local xPlayers = ESX.GetExtendedPlayers('job', job)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.job.grade == grade then
						xTarget.setJob(job, grade)
					end
				end
				cb()
			end)
		else
			print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary over the config limit for ^5%s^7!'):format(source, job))
			cb()
		end
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary for ^5%s^7!'):format(source, job))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_society:setJobLabel', function(source, cb, job, grade, label)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == job and Config.BossGrades[xPlayer.job.grade_name] then
			MySQL.update('UPDATE job_grades SET label = ? WHERE job_name = ? AND grade = ?', {label, job, grade},
			function(rowsChanged)
				Jobs[job].grades[tostring(grade)].label = label
				ESX.RefreshJobs()
				Wait(1)
				local xPlayers = ESX.GetExtendedPlayers('job', job)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.job.grade == grade then
						xTarget.setJob(job, grade)
					end
				end
				cb()
			end)
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobLabel for ^5%s^7!'):format(source, job))
		cb()
	end
end)

local getOnlinePlayers, onlinePlayers = false, nil
ESX.RegisterServerCallback('esx_society:getOnlinePlayers', function(source, cb)
	if getOnlinePlayers == false and onlinePlayers == nil then 
		getOnlinePlayers, onlinePlayers = true, {}
		
		local xPlayers = ESX.GetExtendedPlayers() 
		for _, xPlayer in pairs(xPlayers) do
			table.insert(onlinePlayers, {
				source = xPlayer.source,
				identifier = xPlayer.identifier,
				name = xPlayer.name,
				job = xPlayer.job
			})
		end 
		cb(onlinePlayers)
		getOnlinePlayers = false
		Wait(1000) 
		onlinePlayers = nil
		return
	end
	while getOnlinePlayers do Wait(0) end
	cb(onlinePlayers)
end)


ESX.RegisterServerCallback('esx_society:getVehiclesInGarage', function(source, cb, societyName)
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Attempting To get a non-existing society - %s!'):format(societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		cb(garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:isBoss', function(source, cb, job)
	cb(isPlayerBoss(source, job))
end)

function isPlayerBoss(playerId, job)
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer.job.name == job and Config.BossGrades[xPlayer.job.grade_name] then
		return true
	else
		print(('esx_society: %s attempted open a society boss menu!'):format(xPlayer.identifier))
		return false
	end
end

function WashMoneyCRON(d, h, m)
	MySQL.query('SELECT * FROM society_moneywash', function(result)
		for i = 1, #result, 1 do
			local society = GetSociety(result[i].society)
			local xPlayer = ESX.GetPlayerFromIdentifier(result[i].identifier)

			TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
				account.addMoney(result[i].amount)
			end)

			if xPlayer then
				Config.NotificationServer(nil, TranslateCap('you_have_laundered', ESX.Math.GroupDigits(result[i].amount)), 'success', xPlayer.source)
			end
		end
		MySQL.update('DELETE FROM society_moneywash')
	end)
end


TriggerEvent('cron:runAt', 3, 0, WashMoneyCRON)
