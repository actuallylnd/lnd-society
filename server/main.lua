local Jobs = {}
local RegisteredSocieties = {}

function sendToDiscord(title, message, xPlayer, society, amount)
    local webhook = Config.Webhook
    local playerName = GetPlayerName(xPlayer.source)
    local discordMessage = {
        username = 'Society Logger',
        embeds = {
            {
                title = title,
                description = message,
                color = 3447003,
                fields = {
                    { name = 'Player', value = playerName, inline = true },
                    { name = 'Society', value = society, inline = true },
                    { name = 'Amount', value = '$' .. ESX.Math.GroupDigits(amount), inline = true },
                },
                footer = {
                    text = os.date('%Y-%m-%d %H:%M:%S'),  
                }
            }
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode(discordMessage), { ['Content-Type'] = 'application/json' })
end


function LoadSocietiesFromDatabase()
    local result = MySQL.Sync.fetchAll('SELECT * FROM addon_account WHERE name LIKE "society_%"', {})
    
    if #result == 0 then
        print("No societies found in database.")
        return
    end

    for i=1, #result, 1 do
        local society = {
            name = result[i].name, 
            label = result[i].label,
            account = result[i].name,  
            datastore = nil, 
            inventory = nil,
            data = nil 
        }
        table.insert(RegisteredSocieties, society)
        --print(('Society loaded: %s (label: %s)'):format(society.name, society.label))
    end
end


function GetSociety(name)
    local societyName = 'society_'..name

    if #RegisteredSocieties == 0 then
        LoadSocietiesFromDatabase()
    end

    for i=1, #RegisteredSocieties, 1 do
        if RegisteredSocieties[i].name == societyName then
            --print('Found society:', RegisteredSocieties[i].name)
            return RegisteredSocieties[i]
        end
    end

    print('Society not found: ', societyName)
    return nil
end


MySQL.ready(function()

	LoadSocietiesFromDatabase()


	local result = MySQL.Sync.fetchAll('SELECT * FROM jobs', {})

	for i=1, #result, 1 do
		Jobs[result[i].name] = result[i]
		Jobs[result[i].name].grades = {}
	end

	local result2 = MySQL.Sync.fetchAll('SELECT * FROM job_grades', {})

	for i=1, #result2, 1 do
		Jobs[result2[i].job_name].grades[tostring(result2[i].grade)] = result2[i]
	end
end)

AddEventHandler('esx_society:registerSociety', function(name, label, account, datastore, inventory, data)
	local found = false

	local society = {
		name = name,
		label = label,
		account = account,
		datastore = datastore,
		inventory = inventory,
		data = data
	}

	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			found, RegisteredSocieties[i] = true, society
			break
		end
	end

	if not found then
		table.insert(RegisteredSocieties, society)
	end
end)

AddEventHandler('esx_society:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('esx_society:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

RegisterServerEvent('esx_society:withdrawMoney')
AddEventHandler('esx_society:withdrawMoney', function(societyName, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local society = GetSociety(societyName)
    amount = ESX.Math.Round(tonumber(amount))

    if 'society_'..xPlayer.job.name == society.name then
        TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
            if account and amount > 0 and account.money >= amount then
                account.removeMoney(amount)
                xPlayer.addMoney(amount)

                MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
                    ['@identifier'] = xPlayer.identifier
                }, function(result)
                    if result and #result > 0 then
                        local fullName = result[1].firstname .. ' ' .. result[1].lastname
                        local logMessage = _U('log_withdraw', fullName, xPlayer.identifier, amount, society.name)
                        
                        sendToDiscord('Society Withdrawal', logMessage, xPlayer, society.name, amount)

                        --print(logMessage) 
                    end
                end)

                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    type = 'success',
                    description = _U('have_withdrawn', ESX.Math.GroupDigits(amount))
                })
            else
                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    type = 'error',
                    description = _U('invalid_amount')
                })
            end
        end)
    else
        print(('esx_society: %s attempted to withdraw money!'):format(xPlayer.identifier))
    end
end)




RegisterServerEvent('esx_society:depositMoney')
AddEventHandler('esx_society:depositMoney', function(societyName, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local society = GetSociety(societyName)
    amount = ESX.Math.Round(tonumber(amount))

    if 'society_'..xPlayer.job.name == society.name then
        if amount > 0 and xPlayer.getMoney() >= amount then
            TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
                if account then
                    xPlayer.removeMoney(amount)
                    account.addMoney(amount)

                    MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
                        ['@identifier'] = xPlayer.identifier
                    }, function(result)
                        if result and #result > 0 then
                            local fullName = result[1].firstname .. ' ' .. result[1].lastname
                            local logMessage = _U('log_deposit', fullName, xPlayer.identifier, amount, society.name)

                            sendToDiscord('Society Deposit', logMessage, xPlayer, society.name, amount)

                            --print(logMessage)  
                        end
                    end)

                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'success',
                        description = _U('have_deposited', ESX.Math.GroupDigits(amount))
                    })
                else
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'error',
                        description = _U('invalid_amount')
                    })
                end
            end)
        else
            TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                type = 'error',
                description = _U('invalid_amount')
            })
        end
    else
        print(('esx_society: %s attempted to deposit money!'):format(xPlayer.identifier))
    end
end)

RegisterServerEvent('esx_society:washMoney')
AddEventHandler('esx_society:washMoney', function(society, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local account = xPlayer.getAccount('black_money')
    amount = ESX.Math.Round(tonumber(amount))

    if xPlayer.job.name == society then
        if amount and amount > 0 and account.money >= amount then
            xPlayer.removeAccountMoney('black_money', amount)

            MySQL.Async.execute('INSERT INTO society_moneywash (identifier, society, amount) VALUES (@identifier, @society, @amount)', {
                ['@identifier'] = xPlayer.identifier,
                ['@society'] = society,
                ['@amount'] = amount
            }, function(rowsChanged)
                MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
                    ['@identifier'] = xPlayer.identifier
                }, function(result)
                    if result and #result > 0 then
                        local fullName = result[1].firstname .. ' ' .. result[1].lastname
                        local logMessage = _U('log_launder', fullName, xPlayer.identifier, amount, society)
                        
                        sendToDiscord('Money Laundering', logMessage, xPlayer, society, amount)

                        --print(logMessage) 
                    end
                end)

                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    type = 'success',
                    description = _U('you_have', ESX.Math.GroupDigits(amount))
                })
            end)
        else
            TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                type = 'error',
                description = _U('invalid_amount')
            })
        end
    else
        print(('esx_society: %s attempted to call washMoney!'):format(xPlayer.identifier))
    end
end)


RegisterServerEvent('esx_society:putVehicleInGarage')
AddEventHandler('esx_society:putVehicleInGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('esx_society:removeVehicleFromGarage')
AddEventHandler('esx_society:removeVehicleFromGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

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

	if society then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			cb(account.money)
		end)
	else
		cb(0)
	end
end)

ESX.RegisterServerCallback('esx_society:getEmployees', function(source, cb, society)
	MySQL.Async.fetchAll('SELECT firstname, lastname, identifier, job, job_grade FROM users WHERE job = @job ORDER BY job_grade DESC', {
		['@job'] = society
	}, function (results)
		local employees = {}

		for i = 1, #results, 1 do
			local fullName = results[i].firstname .. ' ' .. results[i].lastname
			
			table.insert(employees, {
				name       = fullName,
				identifier = results[i].identifier,
				job = {
					name        = results[i].job,
					label       = Jobs[results[i].job].label,
					grade       = results[i].job_grade,
					grade_name  = Jobs[results[i].job].grades[tostring(results[i].job_grade)].name,
					grade_label = Jobs[results[i].job].grades[tostring(results[i].job_grade)].label
				}
			})
		end
		cb(employees)
	end)
end)


ESX.RegisterServerCallback('esx_society:getJob', function(source, cb, society)
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

ESX.RegisterServerCallback('esx_society:setJob', function(source, cb, identifier, job, grade, type)
    local xPlayer = ESX.GetPlayerFromId(source)
    local isBoss = xPlayer.job.grade_name == Config.BossGrade

    if isBoss then
        local xTarget = ESX.GetPlayerFromIdentifier(identifier)

        if xTarget then
            xTarget.setJob(job, grade)

            MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
                ['@identifier'] = identifier
            }, function(result)
                if result and #result > 0 then
                    local fullName = result[1].firstname .. ' ' .. result[1].lastname

                    if type == 'hire' then
                        TriggerClientEvent('ox_lib:notify', xTarget.source, {
                            type = 'success',
                            description = _U('you_have_been_hired', job)
                        })
                    elseif type == 'promote' then
                        TriggerClientEvent('ox_lib:notify', xTarget.source, {
                            type = 'success',
                            description = _U('you_have_been_promoted')
                        })
                    elseif type == 'fire' then
                        TriggerClientEvent('ox_lib:notify', xTarget.source, {
                            type = 'error',
                            description = _U('you_have_been_fired', fullName)
                        })
                    end
                end
            end)

            cb()
        else
            MySQL.Async.execute('UPDATE users SET job = @job, job_grade = @job_grade WHERE identifier = @identifier', {
                ['@job'] = job,
                ['@job_grade'] = grade,
                ['@identifier'] = identifier
            }, function(rowsChanged)
                cb()
            end)
        end
    else
        print(('esx_society: %s attempted to setJob'):format(xPlayer.identifier))
        cb()
    end
end)



ESX.RegisterServerCallback('esx_society:setJobSalary', function(source, cb, job, grade, salary)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.job.name == job and xPlayer.job.grade_name == Config.BossGrade then
        if salary <= Config.MaxSalary then
            MySQL.Async.execute('UPDATE job_grades SET salary = @salary WHERE job_name = @job_name AND grade = @grade', {
                ['@salary']   = salary,
                ['@job_name'] = job,
                ['@grade']    = grade
            }, function(rowsChanged)
                Jobs[job].grades[tostring(grade)].salary = salary
                local xPlayers = ESX.GetPlayers()

                for i = 1, #xPlayers, 1 do
                    local xTarget = ESX.GetPlayerFromId(xPlayers[i])

                    if xTarget.job.name == job and xTarget.job.grade == grade then
                        xTarget.setJob(job, grade)
                    end
                end

                cb(true)
            end)
        else
            print(('esx_society: %s attempted to setJobSalary over config limit!'):format(xPlayer.identifier))
            cb(false)
        end
    else
        print(('esx_society: %s attempted to setJobSalary'):format(xPlayer.identifier))
        cb(false)
    end
end)


ESX.RegisterServerCallback('esx_society:getOnlinePlayers', function(source, cb)
	local xPlayers = ESX.GetPlayers()
	local players = {}

	for i=1, #xPlayers, 1 do
		local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
		table.insert(players, {
			source = xPlayer.source,
			identifier = xPlayer.identifier,
			name = xPlayer.name,
			job = xPlayer.job
		})
	end

	cb(players)
end)

ESX.RegisterServerCallback('esx_society:getVehiclesInGarage', function(source, cb, societyName)
	local society = GetSociety(societyName)

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

	if xPlayer.job.name == job and xPlayer.job.grade_name == Config.BossGrade then
		return true
	else
		print(('esx_society: %s attempted open a society boss menu!'):format(xPlayer.identifier))
		return false
	end
end

function WashMoneyCRON(d, h, m)
    MySQL.Async.fetchAll('SELECT * FROM society_moneywash', {}, function(result)
        for i = 1, #result, 1 do
            local society = GetSociety(result[i].society)
            local xPlayer = ESX.GetPlayerFromIdentifier(result[i].identifier)

            TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
                account.addMoney(result[i].amount)
            end)

            if xPlayer then
                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    type = 'success',
                    description = _U('you_have_laundered', ESX.Math.GroupDigits(result[i].amount))
                })
            end
            MySQL.Async.execute('DELETE FROM society_moneywash WHERE id = @id', {
                ['@id'] = result[i].id
            })
        end
    end)
end


TriggerEvent('cron:runAt', 3, 0, WashMoneyCRON)
