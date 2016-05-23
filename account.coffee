util = require('util')

# 某特定券商的客戶賬戶,其中可能有若干證券賬戶,如滬深A股B股
class ClientAccount # 客戶賬戶
  constructor: (@broker,@id,@password)->

class IBClientAccount extends ClientAccount

### 注意:
  所有英文方法,多是兼容現有Python接口所需,將來會全部改為中文標準名詞
###
###
  options: @broker,@id,@password,@servicePassword
###
class HSClientAccount extends ClientAccount # 滬深賬戶與盈透等國外賬戶不同,各公司不同部分再分解到子法
  constructor: (@FundAccount,options)-> #(@broker,@id,@password,@servicePassword)->
    @資產賬戶 = {}
    @黑名單 = []

    ###* 在資產賬戶中更新以下兩個變量備用勿刪
    *###
    @可售 = []
    @現有 = []

  操作指令:(指令, 回執)->
    ###過濾操作指令

      回執
        指令: 操作指令string
      或
        null
    ###

    回執 switch 指令.操作
      when 'cancelIt' then 指令
      when 'buyIt'
        ###
        須逐步實現以下買入控制:
          1. 排除黑名單,實現
          2. 調整買入數量,令不超比例, 建成了機制
          3. 檢查委託價格
          4. 回報成交狀態
        ###
        if 指令.證券代碼 in @黑名單
          null
        else
          @求資產賬戶(指令.證券代碼).買入評估(指令)
      when 'sellIt'
        @求資產賬戶(指令.證券代碼).賣出評估(指令)
      when 'test_buyIt'
        @求資產賬戶(指令.證券代碼).買入評估(指令)
      when 'test_sellIt'
        @求資產賬戶(指令.證券代碼).賣出評估(指令)


      else null

  查詢簡況: (data, callback)->
    @查詢持倉(data, callback)

  # 並執行止損
  查詢持倉: (data, callback)->
    @現有 = []
    @可售 = []

    ###* 1 更新前  *###
    for key, value of @資產賬戶
      value.準備更新持倉()

    ###* 2 更新中 *###
    for key, tick of data # 保本式止損
      證券 = new Position()
      證券.華泰證券(tick)
      @求資產賬戶(證券.代碼).更新證券表(證券,this,callback)

  ###
    按照目前設計, 此處 回執 不要用
  ###
  查詢資產: (data, 回執)->
    for key, value of data
      unless @資產賬戶[key]?
        @資產賬戶[key] = new @FundAccount(@id)
      @資產賬戶[key].記錄資產(value)


  查可撤單: (data, callback)->
    util.log("got orders data", data)
    # 剛測試不可以? 須查誰用到此處回執,或許之前設計成不回執 callback data


  求資產賬戶:(代碼)=>
    幣種 = switch 代碼[0]
      when '9' then '1'
      when '2' then '2'
      else '0'
    @資產賬戶[幣種]

# 個股持倉狀況,待完善
class Position
  constructor:(@代碼)->

  拷貝: ->
    證券 = new Position(@代碼)
    for key, val of this
      證券[key] = val
    return 證券

  華泰證券:(va)->
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
