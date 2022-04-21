module binance
import json
import net.http
import crypto.hmac
import crypto.sha256

const(
	api_key = "your_api_key_here"
	sec_key = "your_sec_key_here"
)

fn server_time() string
{
	resp := http.get('https://www.binance.com/fapi/v1/time') or {return ""}
	return resp.text.find_between(":","}") //{"serverTime":1640989038042}
}

fn encrypt_message(msg_in string) string
{
  	result := hmac.new(sec_key.bytes(),msg_in.bytes(), sha256.sum, sha256.block_size).hex()
	return result
}

pub fn delete_order(symbol string, order_id string) (Order_cancel,bool)
{
	s_time := server_time()
	base_msg := "symbol=${symbol}&origClientOrderId=${order_id}&timestamp=${s_time}"
	encrypt_msg := encrypt_message(base_msg)

	result := http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/order?${base_msg}&signature=${encrypt_msg}",
	    	method: .delete,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  ) or { return Order_cancel{}, true }


	//curl_cmd := "curl -s -H \"X-MBX-APIKEY: ${api_key}\" -X DELETE \"https://fapi.binance.com/fapi/v1/order?${base_msg}&signature=${encrypt_msg}\""
	//result := os.execute(curl_cmd)

	mut delete_resp := json.decode(Order_cancel, result.text) or {
        //eprintln('Failed to parse json')
        return Order_cancel{}, true // Default initialized and return error
    }

	return delete_resp, false
}

pub fn post_margin_type(symbol string, margin_type string) (Margintype, bool)
{
	s_time := server_time()
	base_msg := "symbol=${symbol}&marginType=${margin_type}&timestamp=${s_time}"
	encrypt_msg := encrypt_message(base_msg)

	  result := http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/marginType?${base_msg}&signature=${encrypt_msg}",
	    	method: .post,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  ) or { return Margintype{}, true }

	mut set_margin_type := json.decode(Margintype, result.text) or {
        return Margintype{}, true // Default initialized and return error
    }
	
	if set_margin_type.code != 200 && set_margin_type.code != -4046  //Success and "no need to change margin type"
	{
		eprintln(":::set margin type:::")
		eprintln("\t[$set_margin_type.code]: $set_margin_type.msg ")
		return set_margin_type,true // return error
	}

	return set_margin_type, false
}

struct Margintype
{
	code int [json:code]
	msg string [json:msg]
}

pub fn post_leverage(symbol string, leverage int) (Leverage, bool)
{
	s_time := server_time()
	base_msg := "symbol=${symbol}&leverage=${leverage}&timestamp=${s_time}"
	encrypt_msg := encrypt_message(base_msg)

	  result := http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/leverage?${base_msg}&signature=${encrypt_msg}",
	    	method: .post,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  ) or { return Leverage{}, true }

	mut set_lvg := json.decode(Leverage, result.text) or {
        return Leverage{}, true // Default initialized and return error
    }
	
	if set_lvg.error_code != 0
	{
		eprintln(":::post_leverage:::")
		eprintln("\t[$set_lvg.error_code]: $set_lvg.error_msg ")
		return set_lvg,true // return error
	}

	return set_lvg, false
}

pub fn post_order(real_exec bool,order_id string,ptype string,symbol string,side string,tif string,qty string,price string,stop_price string) (New_order, bool)
{
	s_time := server_time()
	mut base_msg := ""

	if compare_strings(ptype,"MARKET")==0
	{
		base_msg = "symbol=${symbol}&\
					side=${side}&\
					type=${ptype}&\
					quantity=${qty}&\
					newClientOrderId=${order_id}&\
					timestamp=${s_time}"
	}
	else if compare_strings(ptype,"LIMIT")==0
	{
		base_msg = "symbol=${symbol}&\
					side=${side}&\
					timeInForce=${tif}&\
					type=${ptype}&\
					quantity=${qty}&\
					price=${price}&\
					newClientOrderId=${order_id}&\
					timestamp=${s_time}"
	}
	else if compare_strings(ptype,"TAKE_PROFIT_MARKET")==0 || compare_strings(ptype,"STOP_MARKET")==0
	{
		base_msg = "symbol=${symbol}&\
					side=${side}&\
					type=${ptype}&\
					quantity=${qty}&\
					stopPrice=${stop_price}&\
					newClientOrderId=${order_id}&\
					timestamp=${s_time}"
	}
	else
	{
		base_msg = "symbol=${symbol}&\
					side=${side}&\
					timeInForce=${tif}&\
					type=${ptype}&\
					quantity=${qty}&\
					price=${price}&\
					stopPrice=${stop_price}&\
					newClientOrderId=${order_id}&\
					timestamp=${s_time}"
	}
	encrypt_msg := encrypt_message(base_msg)

	//mut curl_cmd := ""
	mut result := http.Response{}
	if real_exec
	{
		result = http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/order?${base_msg}&signature=${encrypt_msg}",
	    	method: .post,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  		) or { return New_order{}, true }
		//curl_cmd = "curl -s -H \"X-MBX-APIKEY: ${api_key}\" -X POST \"https://fapi.binance.com/fapi/v1/order?${base_msg}&signature=${encrypt_msg}\""
	}
	else
	{
		result = http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/order/test?${base_msg}&signature=${encrypt_msg}",
	    	method: .post,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  		) or { return New_order{}, true }
		//curl_cmd = "curl -s -H \"X-MBX-APIKEY: ${api_key}\" -X POST \"https://fapi.binance.com/fapi/v1/order/test?${base_msg}&signature=${encrypt_msg}\""
	}
	//result := os.execute(curl_cmd)

	mut purch_order := json.decode(New_order, result.text) or {
        //eprintln('Failed to parse json')
        return New_order{},true // Default initialized; return error
    }

	if purch_order.error_code != 0
	{
		ex_struct := binance.get_exchangeinfo()
		symbol_struct := binance.parse_symbols(ex_struct,symbol)
		lot_size := binance.parse_filters(symbol_struct,"LOT_SIZE")
		price_filter := binance.parse_filters(symbol_struct,"PRICE_FILTER")
		eprintln(":::post_order:::")
		eprintln("\t[$purch_order.error_code]: $purch_order.error_msg ")
		eprintln("\t\t[Pass type: $ptype]")
		eprintln("\t\t[Pass qty: $qty] [LOT_SIZE.min_qty: ${lot_size.min_qty}] [LOT_SIZE.max_qty: ${lot_size.max_qty}] [LOT_SIZE.step_size: ${lot_size.step_size}]")
		eprintln("\t\t[Pass price: $price] [PRICE_FILTER.min_price: ${price_filter.min_price}] [PRICE_FILTER.max_price: ${price_filter.max_price}] [PRICE_FILTER.tick_size: ${price_filter.tick_size}]")
		eprintln("\t\t[Pass stop: $stop_price] [PRICE_FILTER.min_price: ${price_filter.min_price}] [PRICE_FILTER.max_price: ${price_filter.max_price}] [PRICE_FILTER.tick_size: ${price_filter.tick_size}]")
		return purch_order,true // return error
	}

	return purch_order,false
}

pub fn get_exchangeinfo() ExchangeInfo
{
	resp := http.get('https://fapi.binance.com/fapi/v1/exchangeInfo') or {return ExchangeInfo{}}

	mut exchange_info := json.decode(ExchangeInfo, resp.text) or {
        return ExchangeInfo{} // Default initialized.
    }

	return exchange_info
}

pub fn get_mark_price(symbol string) f64
{
	resp := http.get('https://fapi.binance.com/fapi/v1/premiumIndex?symbol=${symbol}') or {return 0.00}
	parsed := resp.text.find_between("markPrice\":\"","\"")

	if parsed.len > 0
	{
		return parsed.f64()
	}
	else
	{
		return 0.00
	}
}

pub fn get_prices() []Prices
{
	resp := http.get('https://fapi.binance.com/fapi/v1/ticker/price') or {return []Prices{}}
	
	mut price_info := json.decode([]Prices, resp.text) or {
        return []Prices{} // Default initialized.
    }

	return price_info
}

struct Prices
{
	pub:
	symbol string [json:symbol] 
	price string [json:price]

}

pub fn get_price(symbol string) f64
{
	resp := http.get('https://fapi.binance.com/fapi/v1/ticker/price?symbol=${symbol}') or {return 0.00}
	parsed := resp.text.find_between("\"price\":\"","\"")

	if parsed.len > 0
	{
		return parsed.f64()
	}
	else
	{
		return 0.00
	}
}

pub fn parse_futures_balance_account(acct Future_account, symbol string) (Future_assets, bool)
{
	for asset in acct.assets 
	{
		if compare_strings(asset.asset,symbol)==0
		{
			return asset,false
		}
	}

	return Future_assets{},true  // Not found.
}

pub fn parse_futures_holdings_account(acct Future_account, symbol string) (Future_positions, bool)
{
	for position in acct.positions 
	{
		if compare_strings(position.symbol,symbol)==0
		{
			return position,false
		}
	}

	return Future_positions{},true  // Not found.
}

pub fn parse_spot_balance_account(acct Account, symbol string) (f64,f64)
{
	for entry in acct.balances 
	{
		if compare_strings(entry.asset,symbol)==0
		{
			return entry.free.f64(),entry.locked.f64()
		}
	}

	return 0,0  // Not found.
}

pub fn get_openorders(symbol string) ([]Open_orders,bool)
{
	s_time := server_time()
	base_msg := "symbol=${symbol}&timestamp=${s_time}"
	encrypt_msg := encrypt_message(base_msg)

	 result := http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/openOrders?${base_msg}&signature=${encrypt_msg}",
	    	method: .get,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  ) or { return []Open_orders{}, true }

	//curl_cmd := "curl -s -H \"X-MBX-APIKEY: ${api_key}\" -X GET \"https://fapi.binance.com/fapi/v1/openOrders?${base_msg}&signature=${encrypt_msg}\""
	//result := os.execute(curl_cmd)

	mut open_orders := json.decode([]Open_orders, result.text) or {
        //eprintln('Failed to parse json')
        return []Open_orders{},true // Default initialized.
    }

	return open_orders, false

}

pub fn get_user_trades(symbol string) []User_trades
{
	s_time := server_time()
	base_msg := "symbol=${symbol}&timestamp=${s_time}"
	encrypt_msg := encrypt_message(base_msg)

	result := http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/userTrades?${base_msg}&signature=${encrypt_msg}",
	    	method: .get,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  ) or { return []User_trades{} }


	
	//curl_cmd := "curl -s -H \"X-MBX-APIKEY: ${api_key}\" -X GET \"https://fapi.binance.com/fapi/v1/userTrades?${base_msg}&signature=${encrypt_msg}\""
	//result := os.execute(curl_cmd)

	mut user_trades := json.decode([]User_trades, result.text) or {
        //eprintln('Failed to parse json')
        return []User_trades{} // Default initialized.
    }

	return user_trades
}

pub fn get_spot_account() Account
{
	s_time := server_time()
	base_msg := "timestamp=${s_time}"
	encrypt_msg := encrypt_message(base_msg)

	result := http.fetch(
  	  		url: "https://api.binance.com/api/v3/account?${base_msg}&signature=${encrypt_msg}",
	    	method: .get,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  ) or { return Account{} }

	//curl_cmd := "curl -s -H \"X-MBX-APIKEY: ${api_key}\" -X GET \"https://api.binance.com/api/v3/account?${base_msg}&signature=${encrypt_msg}\""
	//result := os.execute(curl_cmd)

	//Hypothetical: If the root of JSON is in [], then decode to []Account.  And access with bin_acct[0].maker_commission, etc etc.
	mut bin_acct := json.decode(Account, result.text) or {
        //eprintln('Failed to parse json')
        return Account{} // Default initialized.
    }

	return bin_acct
}

pub fn get_futures_account() (Future_account,bool)
{
	s_time := server_time()
	base_msg := "timestamp=${s_time}"
	encrypt_msg := encrypt_message(base_msg)

	result := http.fetch(
  	  		url: "https://fapi.binance.com/fapi/v1/account?${base_msg}&signature=${encrypt_msg}",
	    	method: .get,
  	  		header: http.new_custom_header_from_map({"X-MBX-APIKEY": api_key}) or { panic(err) }
	  ) or { return Future_account{}, true }

	//curl_cmd := "curl -s -H \"X-MBX-APIKEY: ${api_key}\" -X GET \"https://fapi.binance.com/fapi/v1/account?${base_msg}&signature=${encrypt_msg}\""
	//result := os.execute(curl_cmd)

	//Hypothetical: If the root of JSON is in [], then decode to []Account.  And access with bin_acct[0].maker_commission, etc etc.
	mut bin_acct := json.decode(Future_account, result.text) or {
        //eprintln('Failed to parse json')
        return Future_account{},true // Default initialized.
    }

	return bin_acct, false
}

pub fn parse_symbols(exinfo ExchangeInfo,filter_symbol string) Symbols
{
	for key in exinfo.symbols
	{
		if compare_strings(key.symbol,filter_symbol) == 0
		{
			return key
		}
	}
	return Symbols{}
}

pub fn parse_filters(symbols Symbols,filter_type string) Filter
{
	for key in symbols.filters
	{
		if compare_strings(key.filter_type,filter_type) == 0
		{
			return key
		}
	
	}
	return Filter{}
}

pub fn lot_step_size(trading_pair string) string
{
	ex_struct := binance.get_exchangeinfo()
	symbol_struct := binance.parse_symbols(ex_struct,trading_pair)
	lot_size := binance.parse_filters(symbol_struct,"LOT_SIZE")
	return lot_size.step_size
}

pub fn price_tick_size(trading_pair string) string
{
	ex_struct := binance.get_exchangeinfo()
	symbol_struct := binance.parse_symbols(ex_struct,trading_pair)
	price_filter := binance.parse_filters(symbol_struct,"PRICE_FILTER")
	return price_filter.tick_size
}

pub fn get_mark_price_klines(symbol string, interval string, limit string) ([]Mark_price_klines, bool)
{
	mut ret_klines := []Mark_price_klines{}
	resp := http.get('https://fapi.binance.com/fapi/v1/markPriceKlines?symbol=${symbol}&interval=${interval}&limit=${limit}') 
			or { return ret_klines, true }

	sub_split := resp.text.split("],")

	for sub in sub_split
	{
		       
		temp_array := sub.replace_each(["[","","]","","\"",""]).split(",")

		mut new_kline := Mark_price_klines{}

		new_kline.open_time = temp_array[0] 
		new_kline.open_price = temp_array[1] 
		new_kline.high_price = temp_array[2] 
		new_kline.low_price = temp_array[3] 
		new_kline.close_price = temp_array[4] 
		new_kline.ignore1 = temp_array[0] 
		new_kline.close_time = temp_array[5] 
		new_kline.ignore2 = temp_array[6] 
		new_kline.number_bisic = temp_array[7] 
		new_kline.ignore3 = temp_array[8] 
		new_kline.ignore4 = temp_array[9] 
		new_kline.ignore5 = temp_array[10] 

		ret_klines << new_kline
	}

	return ret_klines, false
}

struct Mark_price_klines
{
	pub mut:
	open_time string 
    open_price string
    high_price string
    low_price string
    close_price string
    ignore1 string
    close_time string
    ignore2 string
    number_bisic string
    ignore3 string
    ignore4 string
    ignore5 string
}

pub fn calc_ema(price_history []f64, depth_fast int) f64
{
	mut ema := 0.0
	mut loc_depth_fast := depth_fast

	if price_history.len < depth_fast
	{
		//loc_depth_fast = price_history.len
		return price_history.last()
	}

	short_ema_multiplier := 2/(loc_depth_fast + 1)

	// calculate initial ema, which is just sma
	for i:=0; i< loc_depth_fast;i++
	{
		ema+= price_history[price_history.len-i-1] //(*price_history).end()[-i - 1];
	}

	ema = ema / loc_depth_fast

	// Oldest to newest
	for i:=loc_depth_fast; i>0; i--
	{
		ema += (price_history[price_history.len-i] - ema)* short_ema_multiplier // ((*price_history).end()[-i] - ema) * short_ema_multiplier;
	}

	return ema
}

struct Future_account
{
	pub:
		fee_tier int [json:feeTie]       // account commisssion tier 
		can_trade bool [json:canTrade]   // if can trade
		can_deposit bool [json:canDeposit]     // if can transfer in asset
		can_withdraw bool [json:canWithdraw]    // if can transfer out asset
		update_time int [json:updateTime]
		total_initial_margin f64 [json:totalInitialMargin]    // total initial margin required with current mark price (useless with isolated positions), only for USDT asset
		total_maint_margin string [json:totalMaintMargin]     // total maintenance margin required, only for USDT asset
		total_wallet_balance string [json:totalWalletBalance]     // total wallet balance, only for USDT asset
		total_unrealized_profit string [json:totalUnrealizedProfit]   // total unrealized profit, only for USDT asset
		total_margin_balance string [json:totalMarginBalance]     // total margin balance, only for USDT asset
		total_position_init_margin string [json:totalPositionInitialMargin]    // initial margin required for positions with current mark price, only for USDT asset
		total_open_order_init_margin string [json:totalOpenOrderInitialMargin]   // initial margin required for open orders with current mark price, only for USDT asset
		total_cross_wallet_balance string [json:totalCrossWalletBalance]      // crossed wallet balance, only for USDT asset
		total_cross_un_pnl string [json:totalCrossUnPnl]     // unrealized profit of crossed positions, only for USDT asset
		available_balance string [json:availableBalance]    // available balance, only for USDT asset
		max_withdraw_amount string [json:maxWithdrawAmount]     // maximum amount for transfer out, only for USDT asset
		assets []Future_assets
		positions []Future_positions
}

struct Order_cancel
{
	pub:
		status string [json:status]
}

struct Future_assets
{
	pub:
		asset string [json:asset]            // asset name
		wallet_balance string [json:walletBalance]      // wallet balance
		unrealized_profit string [json:unrealizedProfit]    // unrealized profit
		margin_balance string [json:marginBalance]      // margin balance
		maint_margin string [json:maintMargin]        // maintenance margin required
		init_margin string  [json:initialMargin]   // total initial margin required with current mark price 
		position_init_margin string [json:positionInitialMargin]    //initial margin required for positions with current mark price
		open_order_init_margin string [json:openOrderInitialMargin]   // initial margin required for open orders with current mark price
		cross_wallet_balance string [json:crossWalletBalance]      // crossed wallet balance
		cross_un_pnl string [json:crossUnPnl]      // unrealized profit of crossed positions
		available_balance string [json:availableBalance]       // available balance
		max_withdraw_amount string [json:maxWithdrawAmount]     // maximum amount for transfer out
		margin_available bool [json:marginAvailable]    // whether the asset can be used as margin in Multi-Assets mode
		update_time i64 [json:updateTime] // last update time 
	}

struct Future_positions
{
	pub:
		symbol string [json:symbol]  // symbol name
		initial_margin string [json:initialMargin]   // initial margin required with current mark price 
		maint_margin string [json:maintMargin]     // maintenance margin required
		unrealized_profit string [json:unrealizedProfit]  // unrealized profit
		position_init_margin string [json:positionInitialMargin]      // initial margin required for positions with current mark price
		open_order_init_margin string [json:openOrderInitialMargin]     // initial margin required for open orders with current mark price
		leverage string [json:leverage]      // current initial leverage
		isolated bool [json:isolated]       // if the position is isolated
		entry_price string  [json:entryPrice]    // average entry price
		max_notional string [json:maxNotional]   // maximum available notional with current leverage
		bid_notional string [json:bidNotional]  // bids notional, ignore
		ask_notional string [json:askNotional]  // ask norional, ignore
		position_side string [json:positionSide]     // position side
		position_amt string [json:positionAmt]        // position amount
		update_time i64 [json:updateTime]          // last update time
}

struct Account 
{
	maker_commission int [json: makerCommission] 
	taker_commission int [json: takerCommission]
	buyer_commission int [json: buyerCommission]
	seller_commission int [json: sellerCommission]
	can_trade bool [json: canTrade]
	can_withdraw bool [json: canWithdraw]
	can_deposit bool [json: canDeposit]
	update_time i64 [json: updateTime]
	account_type string [json: accountType]
	balances []Balance [json: balances]
}

struct Balance
{
	asset string
	free string
	locked string
}

struct Leverage
{
	pub:
		leverage int [json:leverage]
		max_notional_value string [json:maxNotionalValue]
		symbol string [json:symbol]
		error_code int [json:code] // populated on error
		error_msg string [json:msg] // populated on error
}

struct ExchangeInfo //exchangeInfo
{
	pub:
		timezone string [json:timezone]
		server_time i64 [json:serverTime]
		symbols []Symbols [json:symbols]
	// TODO rateLimits, exchangeFilters
}

struct Symbols //exchangeInfo
{
	pub:
		symbol string [json:symbol]
		status string [json:status]
		base_asset string [json:baseAsset]
		base_asset_prec int [json:baseAssetPrecision]
		quote_asset string [json:quoteAsset]
		quote_asset_prec int [json:quoteAssetPrecision]
		base_comm_prec int [json:baseCommissionPrecision]
		quote_comm_prec int [json:quoteCommissionPrecision]
		order_types []string [json:orderTypes]
		iceberg_qty bool [json:icebergAllowed]
		oco_allowed bool [json:ocoAllowed]
		quote_order_qty_mkt_allowed bool [json:quoteOrderQtyMarketAllowed]
		is_spot_trading_allowed bool [json:isSpotTradingAllowed]
		is_margin_trading_allowed bool [json:isMarginTradingAllowed]
		filters []Filter [json:filters]
		permissions []string [json:permissions]
}

struct Filter //exchangeInfo (superset of all filter results)
{
	pub:
		filter_type string [json:filterType]
		min_price string [json:minPrice]
		max_price string [json:maxPrice]
		min_qty string [json:minQty]
		max_qty string [json:maxQty]
		multiplier_up string [json:multiplierUp]
		multiplier_down string [json:multiplierDown]
		avg_price_mins int [json:avgPriceMins]
		step_size string [json:stepSize]
		tick_size string [json:tickSize]
		min_notional string [json:minNotional]
		apply_to_market bool [json:applyToMarket]
		limit int [json:limit]
		max_num_orders int [json:maxNumOrders]
		max_num_algo_orders int [json:maxNumAlgoOrders]
		max_num_iceberg_orders int [json:maxNumIcebergOrders]
		max_position string [json:maxPosition]
}


struct New_order
{
	pub:
		symbol string [json:symbol]
		order_id int [json:orderId]
		order_list_id int [json:orderListId]
		client_order_id string [json:clientOrderId]
		transact_time i64 [json:transactTime]
		error_code int [json:code] // populated on error
		error_msg string [json:msg] // populated on error
}

struct User_trades
{
	pub:
 		buyer bool [json:buyer]
    	commission string [json:commission]
    	commission_asset string [json:commissionAsset]
    	id int [json:id]
    	maker bool [json:maker]
    	order_id int [json:orderId]
    	price string [json:price]
    	qty string [json:qty]
    	quote_qty string [json:quoteQty]
    	realized_pnl string [json:realizedPnl]
    	side string [json:side]
    	position_side string [json:positionSide]
    	symbol string [json:symbol]
    	time i64 [json:time]
}


struct Open_orders
{
	pub:
		symbol string [json:symbol]
		order_id int [json:orderId]
		order_list_id int [json:orderListId]
		client_order_id string [json:clientOrderId]
		price string [json:string]
		orig_qty string [json:origQty]
		executed_qty string [json:executedQty]
		cum_quote_qty string [json:cummulativeQuoteQty]
		status string [json:status]
		time_in_force string [json:timeInForce]
		order_type string [json:@type] // Escape type, as keyword
		side string [json:side]
		stop_price string [json:stopPrice]
		iceberg_qty string [json:icebergQty]
		order_time i64 [json:time]
		update_time i64 [json:updateTime]
		is_working bool [json:isWorking]
		orig_quote_order_qty string [json:origQuoteOrderQty]
}
