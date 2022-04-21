import os
import flag
import binance
import time
import math

fn main()
{
	mut fp := flag.new_flag_parser(os.args)
    
	fp.application('binfuture')
    
	fp.version('v0.0.1\nCopyright (c) 2022 jeffrey -at- ieee.org. All rights \
	reserved.\nUse of this source code (/program) is governed by an MIT \
	license,\nthat can be found in the LICENSE file.')
    
	fp.description('\nExecute Binance futures trading from CLI.')
    fp.skip_executable()

    short_arg := fp.string('short', `s`, "", 'short trading-pair [non-interacive mode]')
	long_arg := fp.string('long', `l`, "", 'long trading-pair [non-interacive mode]')
	pair_arg := fp.string('pair', `p`, "", 'trading-pair [interactive mode]')
	mut sl_arg := fp.string('stoploss', `d`, "", 'stop loss (as %)')
	mut tp_arg := fp.string('takeprofit', `u`, "", 'take profit (as %)')
	leverage_arg := fp.int('leverage', `x`, 1, 'leverage multiplier [default:1]')
	mut spend_arg := fp.int('spend', `c`, 0, 'max spend')
	interactive_arg := fp.bool('interactive', `i`, false, 'interactive mode')

	additional_args := fp.finalize() or {
        eprintln(err)
        println(fp.usage())
        return
	}

	additional_args.join_lines()
	
	////////////////////
	/// PARAM CHECKS ///
	////////////////////
	if short_arg.len > 0 && long_arg.len > 0
	{
		eprintln("Cannot specify both a short and long position!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	if short_arg.len == 0 && long_arg.len == 0 && !interactive_arg
	{
		eprintln("Must specify a short or a long position!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	if spend_arg == 0
	{
		eprintln("Must specify a spend amount!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	if sl_arg.len== 0 || tp_arg.len==0
	{
		eprintln("Must specify both a take-profit and stop-loss!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	if (short_arg.len > 0 || long_arg.len > 0) && interactive_arg
	{
		eprintln("Cannot specify long or short position in interactive mode.\n")
		println(fp.usage())
		exit(0)
	}
	if pair_arg.len == 0 && interactive_arg
	{
		eprintln("Must specify a trading pair in interactive mode.")
		println(fp.usage())
		exit(0)
	}

	mut trading_pair := ""
	mut is_long := true

	if short_arg.len >0 
	{
		trading_pair = short_arg
		is_long = false
	}
	else if long_arg.len >0 
	{	
		trading_pair = long_arg
		is_long = true
	}
	else if pair_arg.len >0
	{
		trading_pair = pair_arg
	}

	println("")

		_,lvg_error := binance.post_leverage(trading_pair,leverage_arg)
	if lvg_error
	{
	 	println("Error occured in setting leverage! Aborting...")
		exit(0)
	}
	else
	{
		println("[Leverage]\t${leverage_arg}")
	}


	_,margin_type_error := binance.post_margin_type(trading_pair,"ISOLATED")
	if margin_type_error
	{
	 	println("Error occured in setting margin type! Aborting...")
		exit(0)
	}
	else
	{
		println("[Margin Type]\tISOLATED")
	}

	my_acct,_ := binance.get_futures_account()

	bnb_asset,_ := binance.parse_futures_balance_account(my_acct,"BNB")
	println("[BNB Wallet Balance]\t${bnb_asset.wallet_balance.f64():0.2f}\n")

	usdt_asset,_ := binance.parse_futures_balance_account(my_acct,"USDT")
	println("[USDT Wallet Balance]\t${usdt_asset.wallet_balance.f64():0.2f}")
	println("[USDT Margin Balance]\t${usdt_asset.margin_balance.f64():0.2f}")

	mut file_rec := os.open_append("log/bincmd.log") or {panic(err)}
	file_rec.writeln("${time.now()}\t${usdt_asset.wallet_balance.f64():0.2f}") or {panic(err)}
	file_rec.close()

	// If paramter exceeds wallet balance, re-adjust
	if spend_arg > usdt_asset.margin_balance.f64()
	{
		spend_arg = usdt_asset.margin_balance.int()
	}
	max_qty,curr_price := calculate_max_qty(spend_arg*leverage_arg,trading_pair)
	println("[SPEND AMT]\t$spend_arg")
	println("[CP]\t\t$curr_price")
	println("[MAX QTY]\t$max_qty")
	
	mut user_in := ""
	for interactive_arg==true
	{
		println("")
		user_in = os.input("Execute command (h for help):")
		
		if compare_strings(user_in,"h") == 0
		{
			println("[l] go long")
			println("[s] go short")
			continue
		}

		if compare_strings(user_in,"l") == 0 ||
		   compare_strings(user_in,"s") == 0
		{
			println("")
			break
		}
	}

	mut active_order := Working_order{}
	if interactive_arg==true
	{
		pass_qty,pass_price := calculate_max_qty(spend_arg*leverage_arg,trading_pair)
		println("[SPEND AMT]\t$spend_arg")
		println("[CP]\t\t$pass_price")
		println("[MAX QTY]\t$pass_qty")

		if compare_strings(user_in,"l") == 0
		{
			active_order = test_purchase(true,true,trading_pair,tp_arg.f64(),sl_arg.f64(),pass_qty,leverage_arg)
		}
		if compare_strings(user_in,"s") == 0
		{
			active_order = test_purchase(false,true,trading_pair,tp_arg.f64(),sl_arg.f64(),pass_qty,leverage_arg)
		}
	}
	else if interactive_arg==false
	{
		test_purchase(is_long,true,trading_pair,tp_arg.f64(),sl_arg.f64(),max_qty,leverage_arg)
	}

	
	go monitor_status(&active_order) // Pass reference so can monitor in thread.

	println("\nInitiated: ${time.now()}")
	println("\nHit 'c' (+enter) to close position early.")

	for true
	{
		println("")
		println("")
		user_in = os.input("")
		
		if compare_strings(user_in,"h") == 0
		{
			println("[c] close positions")
			continue
		}
		else if compare_strings(user_in,"c") == 0
		{
			println("")
			println("")
			println("")
			active_order.active = false
			delete_order_set(active_order)
			println("Stopped: ${time.now}")
			break
		}
	}
}

// The maximum quantity can purchase at the current price, with X dollars.
fn calculate_max_qty(spend_amt f64,trading_pair string) (f64,f64) 
{
	ex_struct := binance.get_exchangeinfo()
	symbol_struct := binance.parse_symbols(ex_struct,trading_pair)
	lot_size := binance.parse_filters(symbol_struct,"LOT_SIZE")

	///////////////////
	// CALC MAX QTY ///
	///////////////////
	lot_size_step := lot_size.step_size
	curr_price := binance.get_price(trading_pair)
	max_qty := (spend_amt/curr_price)

	// Accumulate the step size up until hitting the maximum qty
	// Based on wallet balance and current price.
	mut accum := 0.0
	for true
	{
		if accum+lot_size_step.f64() > max_qty
		{
			break
		}
		else
		{
			accum += lot_size_step.f64()
		}
	}

	// Get rid of floating point error....
	if lot_size.step_size.contains(".1")
	{
		accum = round_to_digits(accum,1)
	}
	else if lot_size.step_size.contains(".01")
	{
		accum = round_to_digits(accum,2)
	}
	else if lot_size.step_size.contains(".001")
	{
		accum = round_to_digits(accum,3)
	}
	else if lot_size.step_size.contains(".0001")
	{
		accum = round_to_digits(accum,4)
	}
	else if lot_size.step_size.contains(".00001")
	{
		accum = round_to_digits(accum,5)
	}
	else
	{
		accum = round_to_digits(accum,0)
	}

	// Check if the qty is < min_qty, > max_qty
	if accum < lot_size.min_qty.f64() || accum > lot_size.max_qty.f64()
	{
		return 0,curr_price
	}

	// Finally check if the qty purchase would be < min price, > max price filter
	// price_filter := binance.parse_filters(symbol_struct,"PRICE_FILTER")
	// if accum*curr_price < price_filter.min_price.f64() || accum*curr_price > price_filter.max_price.f64()
	// {
	// 	return 0,curr_price
	// }

	return accum,curr_price
}

fn monitor_status(working_order &Working_order)
{
	for true
	{
		time.sleep(500_000_000)

		if !working_order.active
		{
			println("Stopping monitoring thread...\t[OK]")
			return
		}

		is_orphaned := delete_orphaned_orders(working_order)

		if is_orphaned
		{
			return
		}

		curr_price := binance.get_price(working_order.trading_pair)

		my_acct,my_acct_err := binance.get_futures_account()
		
		if my_acct_err // Parsing error
		{
			continue
		}

		future_holding,future_holding_err := binance.parse_futures_holdings_account(my_acct,working_order.trading_pair)
		
		if future_holding_err // Parsing error
		{
			continue
		}

		unreal_prof := future_holding.unrealized_profit.f64()
		exit_fee := curr_price * working_order.executed_qty.f64() * .0004 *.90 // Market taker fee
		postfee_pnl := unreal_prof - working_order.entry_fee - exit_fee
		postfee_roe := (postfee_pnl / (working_order.entry_price*working_order.executed_qty.f64()))*100* working_order.leverage

		print("\e[1A") // Move cursor up one row.
		print("\e[2K") // Erase entire current line.
		println("[Unrealized PNL] ${future_holding.unrealized_profit.f64():+0.2f} \
		         [Post-fee PNL] ${postfee_pnl:+0.2f} \
				 [ROE %] ${postfee_roe:+0.2f}")
	}
}

fn send_email(subject string,body string)
{
	os.execute('sendemail -f alert@chipnetics.com -t 7807172155@msg.telus.com -u "$subject" -m "$body" -s mail.chipnetics.com:50 -xu jeff@chipnetics.com -xp N2smH]=J.8')
}


fn test_purchase(is_long bool, real_mode bool,trading_pair string,tp_perc f64,sl_perc f64,qty f64, lev f64) Working_order
{
	take_profit_dec := tp_perc/100
	stop_loss_dec := sl_perc/100

	mut working_order := Working_order{}
	
	precised_qty := "${qty}"
	mut purch_pos := ""
	mut tp_sl_pos := ""

	if is_long
	{		
		purch_pos = "BUY"
		tp_sl_pos = "SELL"
	}
	else
	{
		purch_pos = "SELL"
		tp_sl_pos = "BUY"
	}
	
	price_tick := binance.price_tick_size(trading_pair)
	mut precised_price := ""

	curr_price := binance.get_price(trading_pair)
	mut limit_price := curr_price

	if is_long  // bit of a edge to get more qty on IOC
	{
		limit_price = curr_price*1.002
	}
	else
	{
		limit_price = curr_price*0.998
	}

	if price_tick.contains(".1")
	{
		precised_price =  "${limit_price:0.1f}"
	}
	else if price_tick.contains(".01")
	{
		precised_price = "${limit_price:0.2f}"
	}
	else if price_tick.contains(".001")
	{
		precised_price = "${limit_price:0.3f}"
	}
	else if price_tick.contains(".0001")
	{
		precised_price = "${limit_price:0.4f}"

	}
	else if price_tick.contains(".00001")
	{
		precised_price = "${limit_price:0.5f}"
	}
	else
	{
		precised_price = "${limit_price:0.0f}"
	}

	print("Placing MARKET...............")
	// Don't want to use MARKET order here, if there's not enough liquidity volume and order is high value, you can get
	// really scattered prices.  IOC will get as much qty as possible (of that requested), at the limit
	// price provided. IOC LIMIT is still a taker commission however.
	_,purch_err := binance.post_order(real_mode,"mk1","LIMIT",trading_pair,purch_pos,"IOC",precised_qty,precised_price,"")
	if purch_err
	{
		println("\t[FAIL]")
	}
	else
	{
		println("\t[OK]")

		// Check holdings account to see the entry price and quantity
		my_acct,_ := binance.get_futures_account()
		future_holding,_ := binance.parse_futures_holdings_account(my_acct,trading_pair)
		
		entry_price_str := future_holding.entry_price

		mut take_profit := 0.0
		mut stop_loss := 0.0

		if is_long
		{		
			take_profit = entry_price_str.f64()*(1+take_profit_dec)
			stop_loss = entry_price_str.f64()*(1-stop_loss_dec)
		}
		else
		{
			take_profit = entry_price_str.f64()*(1-take_profit_dec)
			stop_loss = entry_price_str.f64()*(1+stop_loss_dec)
		}

		// Get rid of floating point error....
		mut precised_takeprofit :=  ""
		mut precised_stoploss := ""

		if price_tick.contains(".1")
		{
			precised_takeprofit =  "${take_profit:0.1f}"
			precised_stoploss = "${stop_loss:0.1f}"
		}
		else if price_tick.contains(".01")
		{
			precised_takeprofit = "${take_profit:0.2f}"
			precised_stoploss = "${stop_loss:0.2f}"
		}
		else if price_tick.contains(".001")
		{
			precised_takeprofit = "${take_profit:0.3f}"
			precised_stoploss = "${stop_loss:0.3f}"
		}
		else if price_tick.contains(".0001")
		{
			precised_takeprofit = "${take_profit:0.4f}"
			precised_stoploss = "${stop_loss:0.4f}"
		}
		else if price_tick.contains(".00001")
		{
			precised_takeprofit = "${take_profit:0.5f}"
			precised_stoploss = "${stop_loss:0.5f}"
		}
		else
		{
			precised_takeprofit = "${take_profit:0.0f}"
			precised_stoploss = "${stop_loss:0.0f}"
		}

		// position_amt will be negative on shorts... make positive.
		mut abs_position := future_holding.position_amt
		if abs_position.starts_with("-")
		{
			abs_position = abs_position.all_after("-")
		}

		print("Placing TAKE_PROFIT_MARKET...")
		//_,purch_err1 := binance.post_order(real_mode,"tp1","TAKE_PROFIT_MARKET",trading_pair,tp_sl_pos,"",abs_position,"",precised_takeprofit)
		_,purch_err1 := binance.post_order(real_mode,"tp1","LIMIT",trading_pair,tp_sl_pos,"GTC",abs_position,precised_takeprofit,"")
		if purch_err1
		{
			println("\t[FAIL]")
		}
		else
		{
			println("\t[OK]")
			print("Placing STOP_MARKET..........")
			_,purch_err2 := binance.post_order(real_mode,"sl1","STOP_MARKET",trading_pair,tp_sl_pos,"",abs_position,"",precised_stoploss)
			if purch_err2
			{
				println("\t[FAIL]")
			}
			else
			{
				println("\t[OK]")
				working_order.trading_pair = trading_pair
				working_order.entry_price = entry_price_str.f64()
				working_order.entry_fee = entry_price_str.f64()*abs_position.f64()*.0004*.90  // BNB Maker fee
				working_order.executed_qty = precised_qty
				working_order.is_long = is_long
				working_order.stop_loss_id = "sl1"
				working_order.take_profit_id = "tp1"
				working_order.active = true
				working_order.leverage = lev
				
				println("")
				println("CP\t[$curr_price]")
				println("EP\t[$entry_price_str]")
				println("TP\t[$precised_takeprofit]")
				println("SL\t[$precised_stoploss]")
				println("QT\t[$abs_position|$qty]")

				go send_email("PLACE","MO: $trading_pair\nEP: $entry_price_str\nTP: $precised_takeprofit\nSL: $precised_stoploss")
			}
		}
	}

	return working_order
}

// Deletes the root (base purchase) and the associated TP/SL orders for the trading_pair
fn delete_order_set(order Working_order)
{
	mut side:= ""
	if order.is_long
	{		
		side = "SELL"
	}
	else
	{
		side = "BUY"
	}

	print("Closing MARKET...\t\t")
	_,close_err := binance.post_order(true,"cp1","MARKET",order.trading_pair,side,"",order.executed_qty,"","")
	if close_err
	{
		println("[FAIL]")
	}
	else
	{
		println("[OK]")
	}

	print("Closing TAKE_PROFIT_MARKET...\t")
	mut delete_resp, mut delete_err := binance.delete_order(order.trading_pair,order.stop_loss_id)
	if delete_err
	{
		println("[FAIL]")
	}
	else
	{
		println("[OK]")
		
	}

	print("Closing STOP_MARKET...\t\t")
	delete_resp,delete_err = binance.delete_order(order.trading_pair,order.take_profit_id)
	if delete_err
	{
		println("[FAIL]")
	}
	else
	{
		println("[OK]")
		
	}
}

// Deletes TP/SL pair of closed IDs
fn delete_orphaned_orders(entry Working_order) bool
{
	if entry.active==false
	{	
		return true
	}

	open_res,open_err := binance.get_openorders(entry.trading_pair)
	if open_err // Parsing error
	{
		return false // Not sure if orphaned
	}

	mut open_order_ids := []string{}
	for order in open_res
	{
		open_order_ids << order.client_order_id
	}

	// Stop Loss was triggered, delete take profit
	if !open_order_ids.contains(entry.stop_loss_id)
	{
		send_email("LOSS","Stop Loss triggered.")
		println("\t>>> Stop Loss has been triggered.")
		println("\t>>> Deleting related Take Profit order.")
		delete_resp,delete_err := binance.delete_order(entry.trading_pair,entry.take_profit_id)
		if delete_err
		{
			println("\t>>> Error occured in deletion!")
		}
		else
		{
			println("\t>>> Succesfully deleted ${entry.take_profit_id} :: ${delete_resp.status}")
			return true
		}
	}
	// Take profit was triggered, delete stop loss
	else if !open_order_ids.contains(entry.take_profit_id)
	{
		send_email("WIN","Take Profit triggered.")
		println("\t>>> Take Profit has been triggered.")
		println("\t>>> Deleting related Stop Loss order.")
		delete_resp,delete_err := binance.delete_order(entry.trading_pair,entry.stop_loss_id)
		if delete_err
		{
			println("\t>>> Error occured in deletion!")
		}
		else
		{
			println("\t>>> Succesfully deleted ${entry.stop_loss_id} :: ${delete_resp.status}")
			return true
		}
	}
	return false // is not orphaned
}

struct Working_order
{
	mut:
		trading_pair string
		executed_qty string
		entry_price f64
		entry_fee f64
		is_long bool
		stop_loss_id string
		take_profit_id string
		active bool
		leverage f64
}

const (
    mult_const = [
        1.0,
        10.0,
        100.0,
        1_000.0,
        10_000.0,
        100_000.0,
        1_000_000.0,
        10_000_000.0,
        100_000_000.0,
        1_000_000_000.0,
        10_000_000_000.0,
        100_000_000_000.0,
        1_000_000_000_000.0,
        10_000_000_000_000.0,
        100_000_000_000_000.0,
        1_000_000_000_000_000.0,
    ]

    add_const  = [
        0.5,
        0.05,
        0.005,
        0.0005,
        0.00005,
        0.000005,
        0.0000005,
        0.00000005,
        0.000000005,
        0.0000000005,
        0.00000000005,
        0.000000000005,
        0.0000000000005,
        0.00000000000005,
        0.000000000000005,
        0.0000000000000005,
        0.00000000000000005,
    ]
)

fn round(a f64, in_n_d int) f64 {
    if in_n_d <= 0 {
        return f64(int(a))
    }
    mut n_d := in_n_d
    if n_d > 15 {
        n_d = 15
    }
    b := if a < 0 { -a } else { a }
    mut res := i64((b + add_const[n_d]) * mult_const[n_d]) / mult_const[n_d]
    if a < 0 {
        res *= -1
    }
    return res
}

fn round_to_digits(x f64, digits int) f64 {
    d10 := math.pow(10, digits)
    return math.round(d10 * x) / d10
}