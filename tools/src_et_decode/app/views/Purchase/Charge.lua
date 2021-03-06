--
-- Author: Yang Liu
-- Date: 2016-02-22 15:23:46
--
-- module("Charge", package.seeall)

local gt = cc.exports.gt
cc.exports.Charge = {
	
}

local mt = {}

local Json = require("json")

--[[

function Charge.buy(type_, id_)
	openMaskLayer()

	mt.chargeType = type_
	mt.itemid = id_

	mt.chargeTable = require("app/views/Purchase/Recharge")[mt.itemid]

	local payURL = gt.payUrl
	
	if "ios" == device.platform then
		local gameCode = "2"
		-- safeMd5 = gt.get16bitMd5(passportId .. humanId .. sdkUin .. productId .. serverId .. gameCode .. GameServiceKey)
		payURL = string.format("%s?passportId=%s&humanId=%s&sdkUin=%s&productId=%s&serverId=%s&gameCode=%s&safeMd5=%s", 
			gt.payUrl, passportId, humanId, sdkUin, productId, serverId, gameCode, safeMd5)

		--HttpNetwork.setPayURL("", "")
		-- gt.log("ChargePanel:buy == 支付, itemid:" .. mt.itemid)
		-- gt.isRecharging = false
		-- gt.sdkBridge.pay(mt.chargeTable["Cost"], 10001,  mt.itemid)
		-- return
	elseif "android" == device.platform then
	else

	end
	dump(payURL, "payURL")
	local request = network.createHTTPRequest(reviecePayList, payURL, "POST")

	-- request:setPOSTData(self.tal)
	-- request:addRequestHeader("Content-Type:application/json;charset=UTF-8")

	request:start()
end

]]

function Charge.buy(id_)
	Charge.openMaskLayer()

	dump(gt.playerData, "-------player data")

	mt.itemid = id_
	local RechargeConfig = gt.getRechargeConfig()
	mt.chargeTable = RechargeConfig[mt.itemid]

	local luaBridge = require("cocos/cocos2d/luaoc")
	luaBridge.callStaticMethod("AppController", "resetPayResult")

	gt.sdkBridge.pay(mt.chargeTable["Cost"], nil,  mt.itemid)

	Charge.handlePayMessage()
end

function Charge.openMaskLayer()
	if not mt.maskLayer then
		mt.maskLayer = gt.createMaskLayer()
		local runningscene = cc.Director:getInstance():getRunningScene()
		runningscene:addChild(mt.maskLayer, 300)
	end
end

function Charge.closeMaskLayer()
	gt.isRecharging = false
	if mt.maskLayer then
		mt.maskLayer:removeFromParent()
		mt.maskLayer = nil
	end
end

function Charge.handlePayMessage()
	local getPayResult = function ()
		local luaBridge = require("cocos/cocos2d/luaoc")
		local ok, ret = luaBridge.callStaticMethod("AppController", "getPayResult")

		if string.len(ret) > 0 and mt.checkPayResult then
			gt.log("_______the ret is .." .. ret)

			mt.checkPayResult = false

			
			local response = Json.decode(ret)
			local event = response.event
			mt.chargeData = response.chargeData

			gt.log("-----event:" .. event)

			if event == "PAY_SUCCESS" then
				Charge.requestPayFromServer()
			elseif event == "PURCHASE_DISABLE" then
				Charge.closeMaskLayer()
				require("app/views/NoticeTips"):create("购买失败", "您的设备已关闭内购，请去通用—访问限制中设置", nil, nil, true)
			elseif event == "PURCHASE_CANCEL" then
				Charge.closeMaskLayer()
			end

			--获得到地址上传给服务器
			-- local msgToSend = {}
			-- msgToSend.m_msgId = gt.CG_CHAT_MSG
			-- msgToSend.m_type = 4 -- 语音聊天
			-- msgToSend.m_musicUrl = ret
			-- gt.socketClient:sendMessage(msgToSend)


			gt.scheduler:unscheduleScriptEntry(mt.payResultHandler)
			mt.payResultHandler = nil

		end
	end
	mt.checkPayResult = true
	if mt.payResultHandler then
		gt.scheduler:unscheduleScriptEntry(mt.payResultHandler)
		mt.payResultHandler = nil
	end
	mt.payResultHandler = gt.scheduler:scheduleScriptFunc(getPayResult, 0, false)
end

--服务器验证
function Charge.requestPayFromServer()
	local function payResponse()
		mt.xhr:unregisterScriptHandler()
		if mt.xhr.readyState == 4 and (mt.xhr.status >= 200 and mt.xhr.status < 207) then
			local response = Json.decode(mt.xhr.response)
			dump(response, "----验证结果")
			if response.code == 0 then
				local result = response.data.result 
				if result == 0 or result == "0" then
					gt.log("-----购买成功")
					Charge.closeMaskLayer()
					gt.dispatchEvent(gt.EventType.PURCHASE_SUCCESS)
					require("app/views/NoticeTips"):create("购买成功", "房卡购买成功", nil, nil, true)
				else
					gt.log("-----购买失败")
					Charge.closeMaskLayer()
					require("app/views/NoticeTips"):create("购买失败", "购买失败，请联系客服", nil, nil, true)
				end
				
			elseif response.code == "-1" then
				gt.log("-----购买失败")
				Charge.closeMaskLayer()
				require("app/views/NoticeTips"):create("购买失败", "购买失败，请联系客服", nil, nil, true)
			end

			
		elseif mt.xhr.readyState == 1 and mt.xhr.status == 0 then
			gt.log("------请求失败：")
			Charge.requestPayFromServer()
		end
	end

	local chargeData = mt.chargeData
	local limitState = "purchaseLimited"
	local productId = mt.chargeTable["AppStore"]

	local payURL = string.format("%s?receipt=%s&serverCode=%s&userId=%s&unionId=%s&playerType=%s&isPurchaseLimit=%s&productNumber=%s&payWay=%s", gt.payUrl, chargeData, gt.serverCode, gt.playerData.uid, gt.unionid, "P", limitState, productId, gt.sdkBridge.payWay)
	dump("----验证url" .. payURL)

	if not mt.xhr then
        mt.xhr = cc.XMLHttpRequest:new()
        -- mt.xhr:retain()
        mt.xhr.timeout = 10 -- 设置超时时间
    end
    mt.xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON
    mt.xhr:open("POST", payURL)
    mt.xhr:registerScriptHandler(payResponse)
    mt.xhr:send()


	-- local request = network.createHTTPRequest(payResponse, payURL, "POST")
	-- request:start()
	-- Charge.closeMaskLayer()
end

-- start --
--------------------------------
-- @class function setListView
-- @description 设置充值条目
-- @return nil
-- end --
function Charge.reviecePayList(event)
	gt.isRecharging = false

	gt.log("====== ChargePanel:reviecePayList =======")
	local request = event.request

	if event.name ~= "completed" then
		if request:getErrorCode() ~= 0 then
			require("app/views/NoticeTips"):create("purchase fail", request:getErrorMessage(), nil, nil, true)
		end
		return
	end

	local code = request:getResponseStatusCode()

	if code ~= 200 then
		-- 请求结束，但没有返回 200 响应代码
		require("app/views/NoticeTips"):create("http", code, nil, nil, true)
		return
	end

	gt.log("====== 支付列表 ======="..code)

	local buyingItemid = tonumber(mt.itemid)
	local tbl = request:getResponseString() or ""
	dump(tbl)

	local valueTable = string.split(tbl,"&")
	local feedback = tonumber(valueTable[1])

	if tbl and feedback == 6000 then

		-- if "Dev" == ApiBridge:getDistributionChannelString() or "InHouse" == ApiBridge:getDistributionChannelString() or "AppStore" == ApiBridge:getDistributionChannelString() then
		-- 	mt.transactionid = valueTable[2]
		-- 	MessageControl:getInstance():registerMessage(NotificationType.NOTIFICATION_APPSTORE_PAY_IS_SUCCESS, PaySucsses)
		-- 	gt.sdkBridge.pay(mt.chargeTable["Cost"], valueTable[2],  mt.itemid)
		-- 	return
		-- end

	

	else
		require("app/views/NoticeTips"):create("feedback", feedback, nil, nil, true)
		return
	end

end

-- start --
--------------------------------
-- @class function dummyMoneyResult
-- @description 请求充值结果
-- @return nil
-- end --
function Charge.dummyMoneyResult(event)

	dump(event)
	local request = event.request

	if event.name ~= "completed" then
		if request:getErrorCode() ~= 0 then
			-- Message.createMessageBoxWithString(request:getErrorCode() .. ":" .. request:getErrorMessage())
		end
		return
	end

	local code = request:getResponseStatusCode()

	if code ~= 200 then
		-- 请求结束，但没有返回 200 响应代码
		-- Message.createMessageBoxWithString("HTTP: " .. code)
		return
	end

	gt.log("====== 返回信息 ======="..code)

	local result = request:getResponseString()
	if(result == "ok") then
	end
end

-- start --
--------------------------------
-- @class function GooglePaySucsses
-- @description
-- @return nil
-- end --
function Charge.PaySucsses(messageTable)
	gt.log("ChargePanel:PaySucsses 444 ")
	if "AppStore" == gt.sdkBridge.platformID then
		gt.log("支付成功，请求服务器验证！！！")
		openMaskLayer()
		messageTable = messageTable.data

		local inappPurchaseData = messageTable.chargeData

		-- gt.chargeURL = "http://192.168.1.187:8080/game_login/chargeAndroidgoogle.py"

		local orderId = mt.transactionid
		local chargeData = inappPurchaseData
		local amount = mt.chargeTable["Cost"]

		local payURL = string.format("%s?orderId=%s&chargeData=%s&amount=%s", gt.chargeURL, orderId, chargeData, amount)
		gt.log("ChargePanel:AppStore: 111  payURL = "..payURL)

		local request = network.createHTTPRequest(
			function(event)
				local request = event.request

				if event.name ~= "completed" then
					if request:getErrorCode() ~= 0 then
						-- Message.createMessageBoxWithString(request:getErrorCode() .. ":" .. request:getErrorMessage())
					end
					return
				end

				local result = request:getResponseString() or ""
				gt.dumpTab(result)

				local valueTable = string.split(result,"&")
				local feedback = tonumber(valueTable[1])

				if feedback and feedback == 6200 then

					local tab = {
						transactionid = tonumber(mt.transactionid),
						productId = mt.itemid
					}
					requestPayResult(tab)
					
				else
					closeMaskLayer()
					-- Message.createMessageBox(MessageType.MESSAGE_RECHARGE_FAIL, nil)
					-- Message.createMessageBoxWithString("服务器充值失败！！！" .. feedback)
				end
				--gt.dispatchEvent(gt.EventType.PAY_IS_SUCCESS)

			end, payURL, "POST")
		-- request:setPOSTData(strJson)
		-- request:addRequestHeader("Content-Type:application/json;charset=UTF-8")
		request:start()

		return
	end
end

function Charge.paymentSuccess()

end


-- start --
--------------------------------
-- @class function requestPayResult
-- @description 请求充值结果
-- @return nil
-- end --
--[[
function Charge.requestPayResult(tab)
	gt.log("ChargePanel:requestPayResult")

	--gt.log("ChargePanel:requestPayResult: transactionid = "..self.transactionid)

	local chargeCheckDatas=GameDataManager:getInstance():getProductInfo()
	
	-- if gt.sdkBridge.platformID == "googleP" then
		local transactionid = tonumber(tab.transactionid)
		local productId = tonumber(tab.productId)

		local chargeCheckDatas_Datas=ChargeCheckData:new()
		chargeCheckDatas_Datas:SetProductId(productId) --产品id
		chargeCheckDatas_Datas:SetOrderId(transactionid)
		chargeCheckDatas_Datas:SetState(2)--状态：1到账，2未到账，3非法订单

		local isNewOrder = true --是否为新订单

		for i = 1, #chargeCheckDatas do
			local tmpData = chargeCheckDatas[i]
			local tranId = tonumber(tmpData:GetOrderId())
			local prodId = tonumber(tmpData:GetProductId())

			--状态：1到账，2未到账，3非法订单
			local chargeState = tmpData:GetState()

			if transactionid == tranId and productId == prodId then
				isNewOrder = false
				break
			end
		end

		if isNewOrder then
			table.insert(chargeCheckDatas, chargeCheckDatas_Datas)
		end
		
	-- end

	GameDataManager:getInstance():setProductInfo(chargeCheckDatas)

	local curScene = cc.Director:getInstance():getRunningScene()
	if curScene and mt.chargeType == ChargeType.BUY_DIAMOND then
		gt.log("----------注册事件：NOTIFICATION_USER_DATA")
		local handle = handler(curScene, curScene.updateUserInfo)
    	MessageControl:getInstance():registerMessage(NotificationType.NOTIFICATION_USER_DATA, handle)
	end

	scheduler.performWithDelayGlobal(
		function()
			gt.dumpTab(chargeCheckDatas)
			ChargeCGHttpMessage:getInstance():CG_CHARGE_CHECK(chargeCheckDatas)
		end, 2)

end
]]
return Charge