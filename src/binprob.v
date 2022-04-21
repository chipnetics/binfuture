import binance
import rand
import flag
import os
import math

fn main()
{
	mut fp := flag.new_flag_parser(os.args)
    
	fp.application('binprob')
    
	fp.version('v0.0.1\nCopyright (c) 2022 jeffrey -at- ieee.org. All rights \
	reserved.\nUse of this source code (/program) is governed by an MIT \
	license,\nthat can be found in the LICENSE file.')
    
	fp.description('\nGenerate simulation for Binance Futures outcomes.')
    fp.skip_executable()

    short_arg := fp.bool('short', `s`, false, 'short trading-pair')
	long_arg := fp.bool('long', `l`, false, 'long trading-pair')
	pair_arg := fp.string('pair', `p`, "", 'trading-pair')
	minutes_arg := fp.int('minutes', `m`, 1000, 'number of minutes [max 1000]')
	sim_arg := fp.int('iterations', `i`, 100_000, 'number of iterations')
	mut sl_arg := fp.string('stoploss', `d`, "", 'stop loss (as %)')
	mut tp_arg := fp.string('takeprofit', `u`, "", 'take profit (as %)')

	additional_args := fp.finalize() or {
        eprintln(err)
        println(fp.usage())
        return
	}

	additional_args.join_lines()

	////////////////////
	/// PARAM CHECKS ///
	////////////////////
	if pair_arg.len == 0
	{
		eprintln("Must specify a trading pair!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	if tp_arg.len == 0
	{
		eprintln("Must specify a take profit percentage!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	if sl_arg.len == 0
	{
		eprintln("Must specify a stop loss percentage!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	if minutes_arg > 1000
	{
		eprintln("Maximum minutes is 1000!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}

	mut perc_tp_mvmt := 1.00
	mut perc_sl_mvmt := 1.00

	if short_arg && !long_arg
	{
		perc_tp_mvmt = 1-(tp_arg.f64()/100.00)
		perc_sl_mvmt = 1+(sl_arg.f64()/100.00)
	}	
	else if !short_arg && long_arg
	{
		perc_tp_mvmt = 1+(tp_arg.f64()/100.00)
		perc_sl_mvmt = 1-(sl_arg.f64()/100.00)
	}
	else
	{
		eprintln("Cannot specify both a short and long position!\nSee usage below.\n")
		println(fp.usage())
		exit(0)
	}
	
	//perform_lot(sim_arg,minutes_arg,long_arg,perc_tp_mvmt,perc_sl_mvmt)

	closing_times := perform_simulation(pair_arg,sim_arg,minutes_arg,long_arg,perc_tp_mvmt,perc_sl_mvmt)

	// Sims done...
	mut close_dist := map[int]int{}

	for entry in closing_times
	{
		close_dist[ int(math.floor(entry))+1]++
	}

	mut keys := close_dist.keys()
	keys.sort()

	mut cdf := 0.0

	for key in keys
	{
		cdf += f64(close_dist[key])/f64(sim_arg)
		println("$key\t${close_dist[key]}\t${f64(close_dist[key])/f64(sim_arg):0.2f}\t${cdf:0.2f}")
	}
}

fn perform_simulation(pair string,iterations int,minutes int, is_long bool, tp f64, sl f64) []f64
{
	mut kline,_ := binance.get_mark_price_klines(pair,"1m",minutes.str())

	mut price_hist := []History{}

	for entry in kline
	{	
		mut dp := History{}
		dp.low_price = entry.low_price
		dp.high_price = entry.high_price
		price_hist << dp
	}

	mut close_times_hrs := []f64{}

	for iter:=0; iter < iterations; iter++
	{
		start_time := rand.int_in_range(0,minutes) or { panic(err)}
		low := price_hist[start_time].low_price.f64()
		high := price_hist[start_time].high_price.f64()

		if low==high
		{
			continue
		}

		entry_price := rand.f64_in_range(low,high) or { panic(err)}

		for t_pos:= start_time; t_pos < minutes; t_pos++
		{ 
			if !is_long
			{
				if price_hist[t_pos].low_price.f64() < (entry_price*tp) // Short Win
				{
					close_times_hrs << f64(t_pos-start_time)/60.0
					break
				}
				if price_hist[t_pos].high_price.f64() > (entry_price*sl) // Short Loss
				{
					close_times_hrs << 98
					break
				}
			}
			else
			{
				if price_hist[t_pos].high_price.f64() > (entry_price*tp) // Long Win
				{
					close_times_hrs << f64(t_pos-start_time)/60.0
					break
				}
				if price_hist[t_pos].low_price.f64() < (entry_price*sl) // Long Loss
				{
					close_times_hrs << 98
					break
				}
			}
			
			if t_pos == (minutes-1)
			{
				// Unresolved (non-closed)... put at time point 99 (which is outside 1000 minutes)
				// So nothing else will resolve at this time anyhow
				close_times_hrs << 99
				break
			}
		}
		
	}

	return close_times_hrs

}


fn perform_lot(iterations int,minutes int, is_long bool, tp f64, sl f64)
{
	symbols := binance.get_exchangeinfo().symbols

	mut rankings := []Ranking{}

	mut long_short := [true,false]

	println("")
	for index,symbol in symbols
	{
		print("\e[1A") // Move cursor up one row.
		print("\e[2K") // Erase entire current line.
		println("Running $index of ${symbols.len}")


		for pos in long_short
		{

			closing_times := perform_simulation(symbol.symbol,iterations,minutes,pos,tp,sl)

			mut close_dist := map[int]int{}

			for entry in closing_times
			{
				close_dist[ int(math.floor(entry))+1]++
			}

			mut a_rank := Ranking{}
			a_rank.pair = symbol.symbol
			a_rank.hour = close_dist[1]
			a_rank.is_long = pos
			rankings << a_rank

		}
		
	}

	rankings.sort(b.hour > a.hour)

	for elem in rankings
	{
		println("${elem.pair:14}\tlong:${elem.is_long}\t${elem.hour/iterations:0.2f}")
	}

}

struct Ranking
{
	mut:
	pair string
	is_long bool
	hour f64
}

struct History{
	mut:
		low_price string
		high_price string

}