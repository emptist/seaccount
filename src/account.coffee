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

  TODO:
  1. 應該分解成單幣種賬戶,分別管理
  2. 持倉比重均攤

###
class HSClientAccount extends ClientAccount # 滬深賬戶與盈透等國外賬戶不同,各公司不同部分再分解到子法
  constructor: (@broker,@id,@password,@servicePassword)->
    @黑名單 = []
    @可用 = []
    @現有 = []
    @前持倉 = null # 用於前後比較
    @資產 = null
    @前資產 = null # 用於前後比較
    @持倉 = null
    @比重上限 = 0.5
    @最小分倉資金量 = 20000

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
          #console.error "#{obj.代碼}  列入黑名單,不買"
          null
        else if obj.代碼 in @現有
          額度 = Math.min(@剩餘額度(obj.代碼), obj.比重)
          if 額度 < 0
            null
          else
            obj.比重 = 額度
            obj
        else # 還須 等分資金,控制剩餘資金是否購買,不夠須調整比重.等等.
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
    @現有 = []
    @可用 = []
    @持倉 = {}
    ### 此處可對不同類型品種設置不同的止損比重率,
      或可在證券中設定,但每個賬戶的風險控制不同,故應因人制宜
    ###
    for key, tick of data#, "received #{data}"
      # 保本式止損
      代碼 = tick.SecurityCode
      可用數量 = tick.SecurityAvail
      現有數量 = tick.SecurityAmount
      浮動盈虧 = tick.Profit

      @持倉[代碼] = tick
      if 現有數量 > 0
        @現有.push 代碼
      if 可用數量 > 0
        @可用.push 代碼
        if 浮動盈虧 < 0
          command = "sellIt,#{代碼},#{@求止損比重(代碼)},#{tick.LastPrice}"
          callback(command)
        else
          比重 = @應減倉比重(代碼)
          if 比重 > 0
            command = "sellIt,#{代碼},#{比重},#{tick.LastPrice}"
            callback(command)

    unless @前持倉?
      @前持倉 = @持倉

  查詢資產: (data, callback)->
    # util.log("got funds data", data) # callback
    @資產 = data
    unless @前資產?
      # 記錄前收盤後資產以便比較決策
      @前資產 = data
    # 剛測試不可以? 須查誰用到此處回執,或許之前設計成不回執 callback data

  查可撤單: (data, callback)->
    util.log("got orders data", data)
    # 剛測試不可以? 須查誰用到此處回執,或許之前設計成不回執 callback data

  # 可另寫模塊設定保本止損比重
  求止損比重:(代碼)->
    0.618

  ### 查閱資產和持倉狀況,計算該證券比重,對照比重限額,回復是否超重
  ###
  求各幣資產:(代碼)=>
    幣種 = switch 代碼[0]
      when 9 then '1'
      when 2 then '2'
      else '0'
    return @資產[幣種]

  求市值:(代碼)->
    @持倉[代碼].HoldingValue

  求總額:(代碼)->
    @求各幣資產(代碼).TotalAsset

  超重:(代碼)->
    @求市值(代碼) / @求總額(代碼) > @比重上限

  剩餘額度:(代碼)->
    @比重上限 - (@求市值(代碼) / @求總額(代碼))

  應減倉比重:(代碼)->
    if @求各幣資產(代碼).rmb_value < @最小分倉資金量
      0
    else
      ((@求市值(代碼) / @求總額(代碼)) / @比重上限) - 1



module.exports =
  HSClientAccount:HSClientAccount

###
待完成
  求止損比重()
  超重()

###
