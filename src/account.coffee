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

    #@可售 = []
    #@現有 = []

    #@資產賬戶尚未就緒 = true

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
    #@現有 = []
    #@可售 = []

    ###*

      以下代碼有兩次循環

      這是必須的!

      不要試圖合併優化!

    *###

    ###* 1 更新前 循環1 *###
    for key, value of @資產賬戶
      value.準備更新持倉()

    ###* 2 更新中 *###
    for key, tick of data # 保本式止損
      品種 = new Position()
      品種.華泰品種(tick)
      @求資產賬戶(品種.代碼).更新品種(品種,this,callback)

    ###* 3 更新後 循環2
    設計錯誤,已經改由 fund.coffee 更新品種時各自添加拷貝入前持倉
    if @資產賬戶尚未就緒
      for key, value of @資產賬戶
        value.記錄前持倉()
      @資產賬戶尚未就緒 = false
    *###


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
    品種 = new Position(@代碼)
    for key, val of this
      品種[key] = val
    return 品種

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
