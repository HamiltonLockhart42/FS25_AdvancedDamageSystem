ADS_ServiceActionRequestEvent = {}
local ADS_ServiceActionRequestEvent_mt = Class(ADS_ServiceActionRequestEvent, Event)

InitEventClass(ADS_ServiceActionRequestEvent, "ADS_ServiceActionRequestEvent")

ADS_ServiceActionRequestEvent.ACTION = {
    INIT = 1,
    CANCEL = 2,
    COMPLETE = 3
}

function ADS_ServiceActionRequestEvent.emptyNew()
    return Event.new(ADS_ServiceActionRequestEvent_mt)
end

function ADS_ServiceActionRequestEvent.new(vehicle, actionType, serviceType, workshopType, optionOne, optionTwo, optionThree)
    local self = ADS_ServiceActionRequestEvent.emptyNew()
    self.vehicle = vehicle
    self.actionType = actionType or ADS_ServiceActionRequestEvent.ACTION.INIT
    self.serviceType = serviceType or ""
    self.workshopType = workshopType or ""
    self.optionOne = optionOne or ""
    self.optionTwo = optionTwo or ""
    self.optionThree = optionThree == true
    return self
end

function ADS_ServiceActionRequestEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.actionType, 2)
    streamWriteString(streamId, self.serviceType)
    streamWriteString(streamId, self.workshopType)
    streamWriteString(streamId, self.optionOne)
    streamWriteString(streamId, self.optionTwo)
    streamWriteBool(streamId, self.optionThree)
end

function ADS_ServiceActionRequestEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.actionType = streamReadUIntN(streamId, 2)
    self.serviceType = streamReadString(streamId)
    self.workshopType = streamReadString(streamId)
    self.optionOne = streamReadString(streamId)
    self.optionTwo = streamReadString(streamId)
    self.optionThree = streamReadBool(streamId)
    self:run(connection)
end

local function getOptionalStringOrNil(value)
    if value == nil or value == "" then
        return nil
    end

    return value
end

local function hasFarmPermission(connection, vehicle)
    if connection == nil or vehicle == nil or vehicle.getOwnerFarmId == nil then
        return false
    end

    local ownerFarmId = vehicle:getOwnerFarmId()
    if ownerFarmId == nil or ownerFarmId == 0 or connection.farmId == nil or connection.farmId ~= ownerFarmId then
        return false
    end

    local mission = g_currentMission
    if mission ~= nil and mission.accessHandler ~= nil and mission.accessHandler.canFarmAccess ~= nil then
        return mission.accessHandler:canFarmAccess(connection, ownerFarmId)
    end

    return true
end

local function canConnectionControlVehicle(connection, vehicle)
    if connection == nil then
        return true
    end

    if connection.getIsServer ~= nil and connection:getIsServer() then
        return true
    end

    if vehicle == nil or vehicle.getOwnerFarmId == nil then
        return false
    end

    local ownerFarmId = vehicle:getOwnerFarmId()
    if ownerFarmId == nil or ownerFarmId == 0 then
        return false
    end

    return hasFarmPermission(connection, vehicle)
end

function ADS_ServiceActionRequestEvent:run(connection)
    if connection == nil or not connection:getIsServer() then
        return
    end

    if self.vehicle == nil or self.vehicle.spec_AdvancedDamageSystem == nil then
        return
    end

    if not canConnectionControlVehicle(connection, self.vehicle) then
        return
    end

    local action = self.actionType
    if action ~= ADS_ServiceActionRequestEvent.ACTION.INIT and action ~= ADS_ServiceActionRequestEvent.ACTION.CANCEL and action ~= ADS_ServiceActionRequestEvent.ACTION.COMPLETE then
        return
    end
    if action == ADS_ServiceActionRequestEvent.ACTION.INIT then
        self.vehicle:initService(
            self.serviceType,
            self.workshopType,
            getOptionalStringOrNil(self.optionOne),
            getOptionalStringOrNil(self.optionTwo),
            self.optionThree,
            false
        )
    elseif action == ADS_ServiceActionRequestEvent.ACTION.CANCEL then
        self.vehicle:cancelService()
    elseif action == ADS_ServiceActionRequestEvent.ACTION.COMPLETE then
        self.vehicle:completeService()
    end
end

function ADS_ServiceActionRequestEvent.sendInit(vehicle, serviceType, workshopType, optionOne, optionTwo, optionThree)
    if g_client ~= nil and g_client:getServerConnection() ~= nil then
        g_client:getServerConnection():sendEvent(ADS_ServiceActionRequestEvent.new(vehicle, ADS_ServiceActionRequestEvent.ACTION.INIT, serviceType, workshopType, optionOne, optionTwo, optionThree))
    end
end

function ADS_ServiceActionRequestEvent.sendCancel(vehicle)
    if g_client ~= nil and g_client:getServerConnection() ~= nil then
        g_client:getServerConnection():sendEvent(ADS_ServiceActionRequestEvent.new(vehicle, ADS_ServiceActionRequestEvent.ACTION.CANCEL))
    end
end

function ADS_ServiceActionRequestEvent.sendComplete(vehicle)
    if g_client ~= nil and g_client:getServerConnection() ~= nil then
        g_client:getServerConnection():sendEvent(ADS_ServiceActionRequestEvent.new(vehicle, ADS_ServiceActionRequestEvent.ACTION.COMPLETE))
    end
end
