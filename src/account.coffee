# 一種幣種資金狀況的資產賬戶
util = require('util')

class FundAccount # 單幣種資產賬戶
  constructor:(@幣種)->

# 某特定券商的客戶賬戶,其中可能有若干證券賬戶,如滬深A股B股
class ClientAccount # 客戶賬戶
  constructor: (@broker,@id,@password)->

class IBClientAccount extends ClientAccount

### 注意:
  所有英文方法,多是兼容現有Python接口所需,將來會全部改為中文標準名詞
###
class HSClientAccount extends ClientAccount # 滬深賬戶與盈透等國外賬戶不同,各公司不同部分再分解到子法
  constructor: (@broker,@id,@password,@servicePassword)->
    @可用=[]

  操作指令:(obj, 回應)->
    #過濾操作指令,回復操作指令string或null
    回應 switch obj.操作
      when 'cancelIt' then obj
      when 'buyIt'
        ###
        須逐步實現以下買入控制:
          1. 排除黑名單
          1. 調整買入數量,令不超比例
          1. 檢查委託價格
          1. 回報成交狀態
        ###

        ###若已有該品種,查數量不令超重
        ###
        if obj.代碼 in @可用
          console.log obj.代碼, "todo: 持倉品種比重控制"
          obj
        else # 還可以控制剩餘資金是否購買,不夠須調整比重.等等.
          obj

      when 'sellIt'
        if obj.代碼 in @可用 then obj else null
      else null

  查詢簡況: (data, callback)->
    @查詢持倉(data, callback)

  查詢持倉: (data, callback)->
    比重 = (code)-> 0.618 # 此處可對不同類型品種設置不同的止損比重率
    @可用 = []
    for key, tick of data#, "received #{data}"
      # 保本式止損

      code = tick.SecurityCode
      ###
        在@可用中存儲可用證券之代碼
        更新數據庫中的品種代碼表還需要嗎?
      ###
      if tick.SecurityAvail > 0
        @可用.push code
        if tick.Profit < 0
          command = "sellIt,#{code},#{比重(code)},#{tick.LastPrice}"
          callback(command)

    #util.log("seaccount 可用品種:",@可用)
    @持倉 = data

  查詢資產: (data, callback)->
    util.log("got funds data") # callback #, "查詢資產#{data}"

  查可撤單: (data, callback)->
    util.log("got orders data")

module.exports =
  HSClientAccount:HSClientAccount
