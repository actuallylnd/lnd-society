Config = {}

Config.Locale = GetConvar('esx:locale', 'en')
Config.EnableESXIdentity = true
Config.MaxSalary = 3500
Config.Webhook = ''

Config.BossGrades = { 
    ['boss'] = true,
    --['staff1'] = false,
    --['staff2'] = false,
    --['staff3'] = false,
}

Config.Notification = function (title, message, type)

    if type == 'success' then
        lib.notify({title = title,description = message,type = type})
        
        --TriggerEvent('esx:showNotification', message)
    elseif type == 'error' then
        lib.notify({title = title,description = message,type = type})

        --TriggerEvent('esx:showNotification', message)

    elseif type == 'inform' then
        lib.notify({title = title,description = message,type = type})

          --TriggerEvent('esx:showNotification', message)

    elseif type == 'warning' then
        lib.notify({title = title, description = message,type = type})

        --TriggerEvent('esx:showNotification', message)
    end
end

Config.NotificationServer = function (title, message, type, playerId)
    if type == 'success' then
        TriggerClientEvent('ox_lib:notify', playerId, { title = title, description = message, type = type })

        --xPlayer.showNotification(message)
    elseif type == 'error' then
        TriggerClientEvent('ox_lib:notify', playerId, { title = title, description = message, type = type })

        --xPlayer.showNotification(message)
    elseif type == 'inform' then
        TriggerClientEvent('ox_lib:notify', playerId, { title = title, description = message, type = type })

        --xPlayer.showNotification(message)

    elseif type == 'warning' then
        TriggerClientEvent('ox_lib:notify', playerId, { title = title, description = message, type = type })

        --xPlayer.showNotification(message)
    end
end
