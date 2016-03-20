###
  單幣種資產賬戶
###
class FundAccount
  constructor:(賬號)->
    @可售 = []
    @現有 = []
    @前持倉 = null # 用於前後比較
    @賬號 = 賬號
    @資產 = new Capital(賬號)
    @前資產 = null # 用於前後比較
    @持倉 = null
    @比重上限 = 0.5

  最小分倉資金量: ->
    switch @資產.幣名
      when '人民币' then 20000
      when '美元' then 3000
      when '港币' then 20000
      else throw "未知貨幣#{@資產.幣名}"

  # 更新記錄
  記錄資產:(value)->
    @資產.華泰資產(value)

    unless @前資產? # 記錄前收盤後資產以便比較決策
      @前資產 = new Capital(@賬號)
      @前資產.華泰資產(value)

  # 收到新的持倉數據之後先清空原有記錄,準備記錄新數據
  更新持倉: ->
    @現有 = []
    @可售 = []
    @持倉 = {}

  更新品種: (品種)->
    代碼 = 品種.代碼
    @持倉[代碼] = 品種

    if 品種.持倉股數 > 0
      @現有.push 代碼
    if 品種.可售股數 > 0
      @可售.push 代碼
      if 品種.盈虧 < 0
        command = "sellIt,#{代碼},#{@求止損比重(代碼)},#{品種.最近價}"
        callback(command)
      else
        比重 = @應減倉比重(代碼)
        if 比重 > 0
          command = "sellIt,#{代碼},#{比重},#{品種.最近價}"
          callback(command)

  # 每次連接券商接口時,先記錄原先數據以備比較操作
  記錄前持倉:->
    unless @前持倉?
      @前持倉 = @持倉



  # 評估賣出命令 obj, 否決則回復 null
  賣出評估:(obj)->
    if obj.代碼 in @可售
       obj
    else null


  # 評估買入命令 obj, 否決則回復 null
  # 待完善
  買入評估:(obj)->
    #以下代碼並未完善買入比重,待資產賬戶完善後再改
    if obj.代碼 in @現有
      額度 = Math.min(@求剩餘額度(obj.代碼), obj.比重)
      if 額度 < 0
        null
      else
        obj.比重 = 額度
        obj
    else # 還須 等分資金,控制剩餘資金是否購買,不夠須調整比重.等等.
      obj




  應減倉比重:(代碼, 均勻=false)->
    if @求資產總額() < @最小分倉資金量()
      0
    else if 均勻
      (@求市值(代碼) / @求資產總額()) - @求均攤比重() #(1 / @現有.length)
    else
      (@求市值(代碼) / @求資產總額()) - @比重上限

  # 可另寫模塊設定保本止損比重
  求止損比重:(代碼)->
    0.618

  求市值:(代碼)->
    @持倉[代碼].持倉市值 #HoldingValue

  求資產總額: ->
    @資產.資產總值 #TotalAsset

  求均攤比重: ->
    (1 / @現有.length)

  求剩餘額度:(代碼, 均勻=false)->
    上限 = if 均勻 then @求均攤比重() else @比重上限
    上限 - (@求市值(代碼) / @求資產總額())



# 待完善
class Capital
  constructor:(@賬號)->

  華泰資產:(value)-> # 樣例
    @幣種 = value.money_type
    @資產總值 = value.TotalAsset
    @餘額 = value.current_balance
    @可用餘額 = value.AvailableFund
    @可取餘額 = value.fetch_balance
    @證券市值 = value.market_value
    @幣名 = value.money_name
    return this

module.exports = FundAccount
