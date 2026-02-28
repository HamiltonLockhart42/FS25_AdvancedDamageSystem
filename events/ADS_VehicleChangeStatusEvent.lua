ADS_VehicleChangeStatusEvent = {}
local ADS_VehicleChangeStatusEvent_mt = Class(ADS_VehicleChangeStatusEvent, Event)
MessageType.ADS_VEHICLE_CHANGE_STATUS = nextMessageTypeId()

InitEventClass(ADS_VehicleChangeStatusEvent, "ADS_VehicleChangeStatusEvent")

function ADS_VehicleChangeStatusEvent.emptyNew()
    return Event.new(ADS_VehicleChangeStatusEvent_mt)
end

function ADS_VehicleChangeStatusEvent.new(vehicle)
    local self = ADS_VehicleChangeStatusEvent.emptyNew()
    self.vehicle = vehicle

    if vehicle ~= nil and vehicle.spec_AdvancedDamageSystem ~= nil then
        local spec = vehicle.spec_AdvancedDamageSystem
        self.serviceLevel = spec.serviceLevel or 1
        self.conditionLevel = spec.conditionLevel or 1
        self.engineTemperature = spec.engineTemperature or -99
        self.transmissionTemperature = spec.transmissionTemperature or -99
        self.currentState = spec.currentState or ""
        self.plannedState = spec.plannedState or ""
        self.maintenanceTimer = spec.maintenanceTimer or 0
        self.breakdowns = ADS_Utils.serializeBreakdowns(spec.activeBreakdowns or {})
    else
        self.serviceLevel = 1
        self.conditionLevel = 1
        self.engineTemperature = -99
        self.transmissionTemperature = -99
        self.currentState = ""
        self.plannedState = ""
        self.maintenanceTimer = 0
        self.breakdowns = ""
    end

    return self
end

function ADS_VehicleChangeStatusEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteFloat32(streamId, self.serviceLevel)
    streamWriteFloat32(streamId, self.conditionLevel)
    streamWriteFloat32(streamId, self.engineTemperature)
    streamWriteFloat32(streamId, self.transmissionTemperature)
    streamWriteString(streamId, self.currentState)
    streamWriteString(streamId, self.plannedState)
    streamWriteFloat32(streamId, self.maintenanceTimer)
    streamWriteString(streamId, self.breakdowns)
end

function ADS_VehicleChangeStatusEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.serviceLevel = streamReadFloat32(streamId)
    self.conditionLevel = streamReadFloat32(streamId)
    self.engineTemperature = streamReadFloat32(streamId)
    self.transmissionTemperature = streamReadFloat32(streamId)
    self.currentState = streamReadString(streamId)
    self.plannedState = streamReadString(streamId)
    self.maintenanceTimer = streamReadFloat32(streamId)
    self.breakdowns = streamReadString(streamId)
    self:run(connection)
end

function ADS_VehicleChangeStatusEvent:run(connection)
    -- Prevent clients from sending this event payload to the server
    -- Only apply state when the event is being executed on clients
    if connection ~= nil and connection:getIsServer() then
        return
    end

    if self.vehicle == nil or self.vehicle.spec_AdvancedDamageSystem == nil then
        return
    end

    local spec = self.vehicle.spec_AdvancedDamageSystem
    spec.serviceLevel = self.serviceLevel
    spec.conditionLevel = self.conditionLevel
    spec.engineTemperature = self.engineTemperature
    spec.transmissionTemperature = self.transmissionTemperature
    spec.currentState = self.currentState
    spec.plannedState = self.plannedState
    spec.maintenanceTimer = self.maintenanceTimer
    spec.activeBreakdowns = ADS_Utils.deserializeBreakdowns(self.breakdowns)

    self.vehicle:setDamageAmount(math.max(0, 1 - spec.serviceLevel), true)
    self.vehicle:recalculateAndApplyEffects()

    g_messageCenter:publish(MessageType.ADS_VEHICLE_CHANGE_STATUS, self.vehicle)
end

function ADS_VehicleChangeStatusEvent.send(vehicle)
    if g_server ~= nil then
        g_server:broadcastEvent(ADS_VehicleChangeStatusEvent.new(vehicle), nil, nil, vehicle)
    else
        g_eventManager:addEvent(ADS_VehicleChangeStatusEvent.new(vehicle))
    end
end
