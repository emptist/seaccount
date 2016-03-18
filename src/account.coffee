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
    @持倉 = []
    @可用 = []
    @資產 = null
    @黑名單 = []

  操作指令:(obj, 回執)->

    ###過濾操作指令

      回執
        obj: 操作指令string
      或
        null
    ###

    回執 switch obj.操作
      when 'cancelIt' then obj
      when 'buyIt'
        ###
        須逐步實現以下買入控制:
          1. 排除黑名單
          1. 調整買入數量,令不超比例
          1. 檢查委託價格
          1. 回報成交狀態
        ###
        if obj.代碼 in @黑名單
          console.error "#{obj.代碼}  列入黑名單,不買"
          null
        else if obj.代碼 in @持倉
          if 超重(obj.代碼)
            null
          else
            obj
        else # 還可以控制剩餘資金是否購買,不夠須調整比重.等等.
          obj

      when 'sellIt'
        if obj.代碼 in @可用
           obj
        else null

      else null

  查詢簡況: (data, callback)->
    @查詢持倉(data, callback)

  # 並執行止損
  查詢持倉: (data, callback)->
    @持倉 = []
    @可用 = []
    ### 此處可對不同類型品種設置不同的止損比重率,
      或可在證券中設定,但每個賬戶的風險控制不同,故應因人制宜
    ###
    for key, tick of data#, "received #{data}"
      # 保本式止損
      代碼 = tick.SecurityCode
      可用數量 = tick.SecurityAvail
      浮動盈虧 = tick.Profit
      @持倉.push 代碼
      ###
        在@可用中存儲可用證券之代碼
        更新數據庫中的品種代碼表還需要嗎?
      ###
      if 可用數量 > 0
        @可用.push 代碼
        if 浮動盈虧 < 0
          command = "sellIt,#{代碼},#{@求止損比重(代碼)},#{tick.LastPrice}"
          callback(command)

    #util.log("seaccount 可用品種:",@可用)
    @持倉 = data

  查詢資產: (data, callback)->
    util.log("got funds data") # callback #, "查詢資產#{data}"
    @資產 = data

  查可撤單: (data, callback)->
    util.log("got orders data")

  # 可另寫模塊設定保本止損比重
  求止損比重:(代碼)->
    0.618

  ### 查閱資產和持倉狀況,計算該證券比重,對照比重限額,回復是否超重
  ###
  超重:(代碼)->
    console.error "account.coffee >> 待 完成 超重()"
    false

module.exports =
  HSClientAccount:HSClientAccount
