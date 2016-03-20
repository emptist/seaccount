# 一種幣種資金狀況的資產賬戶
util = require('util')
FundAccount = require('./fund')

# 某特定券商的客戶賬戶,其中可能有若干證券賬戶,如滬深A股B股
class ClientAccount # 客戶賬戶
  constructor: (@broker,@id,@password)->

class IBClientAccount extends ClientAccount

### 注意:
  所有英文方法,多是兼容現有Python接口所需,將來會全部改為中文標準名詞

  TODO:
  1. 資產和持倉與前面比較,制定止損
  2. 持倉比重均攤,超額則賣出(完成),買入時也自動均衡
  3. 分解成單幣種賬戶,分別管理

###
class HSClientAccount extends ClientAccount # 滬深賬戶與盈透等國外賬戶不同,各公司不同部分再分解到子法
  constructor: (@broker,@id,@password,@servicePassword)->
    @資產賬戶 = {}
    @黑名單 = []
    @可售 = []
    @現有 = []

    @首次讀取 = true


    # 以下變量可能已經無用,待測試
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
        else
          @求資產賬戶(obj.代碼).買入評估(obj)

      when 'sellIt'
        @求資產賬戶(obj.代碼).賣出評估(obj)

      else null

  查詢簡況: (data, callback)->
    @查詢持倉(data, callback)

  # 並執行止損
  查詢持倉: (data, callback)->
    for key, value of @資產賬戶
      value.更新持倉()


    @現有 = []
    @可售 = []
    @持倉 = {}

    ### 此處可對不同類型品種設置不同的止損比重率,
      或可在證券中設定,但每個賬戶的風險控制不同,故應因人制宜
    ###

    for key, tick of data # 保本式止損
      ###
      代碼 = tick.SecurityCode
      可用數量 = tick.SecurityAvail
      現有數量 = tick.SecurityAmount
      浮動盈虧 = tick.Profit
      @持倉[代碼] = tick
      if 現有數量 > 0
        @現有.push 代碼
      if 可用數量 > 0
        @可售.push 代碼
        if 浮動盈虧 < 0
          command = "sellIt,#{代碼},#{@求止損比重(代碼)},#{tick.LastPrice}"
          callback(command)
        else
          比重 = @應減倉比重(代碼)
          if 比重 > 0
            command = "sellIt,#{代碼},#{比重},#{tick.LastPrice}"
            callback(command)
      ###

      品種 = new Position()
      品種.華泰品種(tick)
      @求資產賬戶(品種.代碼).更新品種(品種,this,callback)

    if @首次讀取
      @首次讀取 = false
      for key, value of @資產賬戶
        value.記錄前持倉()


  ###
    按照目前設計, 此處 回執 不要用
  ###
  查詢資產: (data, 回執)->
    # util.log("got funds data", data)
    for key, value of data
      unless @資產賬戶[key]?
        #幣種 = value.money_type
        #幣名 = value.money_type
        @資產賬戶[key] = new FundAccount(@id)
      @資產賬戶[key].記錄資產(value)

    ###
    @資產 = data # 以下為舊代碼,待評估,或可以不再用
    unless @前資產?
      # 記錄前收盤後資產以便比較決策
      @前資產 = data
    # 剛測試不可以? 須查誰用到此處回執,或許之前設計成不回執 callback data
    ###

  查可撤單: (data, callback)->
    util.log("got orders data", data)
    # 剛測試不可以? 須查誰用到此處回執,或許之前設計成不回執 callback data


  求資產賬戶:(代碼)=>
    幣種 = switch 代碼[0]
      when '9' then '1'
      when '2' then '2'
      else '0'
    @資產賬戶[幣種]







  ###
  # 可另寫模塊設定保本止損比重
  求止損比重:(代碼)->
    0.618

  求各幣資產:(代碼)=>
    @求資產賬戶[代碼].資產

  求市值:(代碼)->
    @持倉[代碼].HoldingValue

  求總額:(代碼)->
    @求各幣資產(代碼).TotalAsset
  ###
  ### 查閱資產和持倉狀況,計算該證券比重,對照比重限額,回復是否超重
  ###
  ###
  超重:(代碼)->
    @求市值(代碼) / @求總額(代碼) > @比重上限

  求剩餘額度:(代碼)->
    @比重上限 - (@求市值(代碼) / @求總額(代碼))

  應減倉比重:(代碼, 均勻=false)->
    if (@求各幣資產(代碼).rmb_value) < @最小分倉資金量()
      0
    else if 均勻
      (@求市值(代碼) / @求總額(代碼)) - (1 / @現有.length)
    else
      (@求市值(代碼) / @求總額(代碼)) - @比重上限
  ###



# 個股持倉狀況,待完善
class Position
  constructor:(@代碼)->

  華泰品種:(va)->
    @序號 = va.index
    @平均買入價 = va.av_buy_price
    @平均收支平衡 = va.av_income_balance
    @成本價 = va.CostPrice
    @持倉股數 = va.SecurityAmount
    @可售股數 = va.SecurityAvail
    @交易所 = va.exchange_name
    @交易所類號 = va.exchange_type
    @標識 = va.hand_flag
    @盈虧 = va.Profit
    @盈虧百分比 = va.income_balance_ratio
    @保本價 = va.keep_cost_price
    @最近價 = va.LastPrice
    @持倉市值 = va.HoldingValue
    @股東賬號 = va.stock_account
    @代碼 = va.SecurityCode
    @名稱 = va.SecurityName
    @超額 = va.extra # 這是我用Python算好的,可以參考,也可不用,因思路不同
    return this



module.exports =
  HSClientAccount:HSClientAccount
