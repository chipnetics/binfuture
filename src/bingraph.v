import binance
import os
import time

fn main()
{	
	os.chdir("symbols") or {
		println("You must have a folder named 'symbols' for the output!")
		exit(0)
	}

    symbols := binance.get_exchangeinfo().symbols
	mut ratios := []Ratio{}
	mut stats := map[string]Stats{}

	mut highest_ratio := 1.0
	mut lowest_ratio := 1.0

	println("")
	for index,symbol in symbols
	{
		print("\e[1A") // Move cursor up one row.
		print("\e[2K") // Erase entire current line.
		println("[${index+1} of ${symbols.len}] $symbol.symbol")

		// Get the last 50 points; the 49th will be the current (unfinished hour)
		// Pop it off, leaving 49 completed hours.
		// The first of those 49 hours is burned for cum_ratio math, leaving 48
		mut kline,_ := binance.get_mark_price_klines(symbol.symbol,"1h","50")
		kline.pop()

		mut file_out := os.create("${symbol.symbol}.txt") ?  
        
		file_out.writeln("index\tclose_price\thour_ratio\tcum_ratio") ?

		mut hour_ratio := 0.0
		mut cum_ratio := 0.0
		mut above_1_cnt := 0

		mut a_stats := Stats{}
		if kline.len > 26
		{
			a_stats.hr_1 = (kline[kline.len-1].close_price.f64()/kline[kline.len-2].close_price.f64())*100-100
			a_stats.hr_4 = (kline[kline.len-1].close_price.f64()/kline[kline.len-5].close_price.f64())*100-100
			a_stats.hr_6 = (kline[kline.len-1].close_price.f64()/kline[kline.len-7].close_price.f64())*100-100
			a_stats.hr_8 = (kline[kline.len-1].close_price.f64()/kline[kline.len-9].close_price.f64())*100-100
			a_stats.hr_12 = (kline[kline.len-1].close_price.f64()/kline[kline.len-13].close_price.f64())*100-100
			a_stats.hr_24 = (kline[kline.len-1].close_price.f64()/kline[kline.len-25].close_price.f64())*100-100
			a_stats.hr_48 = (kline[kline.len-1].close_price.f64()/kline[kline.len-49].close_price.f64())*100-100
		}
		stats[symbol.symbol] = a_stats

		final_ratio := kline[48].close_price.f64() / kline[1].close_price.f64()
		intercept_24 := kline[24].close_price.f64() / kline[1].close_price.f64()
		lr_24 := (final_ratio- intercept_24)/24
		
		intercept_6 := kline[42].close_price.f64() / kline[1].close_price.f64()
		lr_6 := (final_ratio- intercept_6)/6
	
		mut var_24 := 0.0
		mut var_6 := 0.0

		var_24 = var_24 + 0.0

		for idx,entry in kline
		{

			if idx == 0
			{
				continue
			}
			
			hour_ratio = kline[idx].close_price.f64() / kline[idx-1].close_price.f64()
			cum_ratio = kline[idx].close_price.f64() / kline[1].close_price.f64()

			// Variance for last 24 hours
			if idx > 23
			{
				temp_ratio_24 := (cum_ratio-(lr_24*(idx-24)))-intercept_24

				if temp_ratio_24< 0
				{
					var_24 += -1*temp_ratio_24
				}
				else
				{
					var_24 += temp_ratio_24
				}				
			}

			// Variance for last 6 hours
			if idx > 41
			{
				temp_ratio_6 := (cum_ratio-(lr_6*(idx-42)))-intercept_6

				if temp_ratio_6 < 0
				{
					var_6 += -1*temp_ratio_6
				}
				else
				{
					var_6 += temp_ratio_6
				}				
			}

			//rolling_hour_ratio += hour_ratio

			if hour_ratio>=1.01
			{
				above_1_cnt++
			}

			if cum_ratio > highest_ratio
			{
				highest_ratio = cum_ratio
			}
			else if cum_ratio < lowest_ratio
			{
				lowest_ratio = cum_ratio
			}
			
            file_out.writeln("${idx}\t$entry.close_price\t${hour_ratio}\t${cum_ratio}") ?	
		}
		file_out.close()

		// Store final cum ratio, for sorting later.
		mut a_ratio := Ratio{}
		a_ratio.pair = symbol.symbol
		a_ratio.ratio = a_stats.hr_6/var_6
		ratios << a_ratio
	}

	//if true{return}

	// Sort the struct 
	ratios.sort(b.ratio < a.ratio)

	print("Generating R scripts..  ")
	theme_str := 'theme(\
		plot.background = element_rect(fill = "#1a202c"),\
		panel.background = element_rect(fill="#2d3748"),\
		axis.text.x = element_text(color="white"),\
		axis.text.y = element_text(color="white"),\
		panel.grid.major = element_blank(),\
		panel.grid.minor = element_blank(),\
		axis.title.x = element_text(color="white"),\
		axis.title.y = element_text(color="white"),\
		plot.title = element_text(color="white"),\
		)'
	
	// One R script for each symbol, so can run concurrent
	for symbol in symbols
	{
		mut r_out := os.create("${symbol.symbol}.r") ? 
		r_out.writeln('library(ggplot2)') ?
		r_out.writeln('library(gridExtra)') ?
		r_out.writeln('library(magick)') ?
		r_out.writeln('scaleFUN <- function(x) sprintf("%.2f", x)') ?

		r_out.writeln('dataset <- read.delim("${symbol.symbol}.txt")') ?
		
		r_out.writeln('closing <- ggplot(data=dataset,aes(y=close_price,x=index)) + \
		               geom_line(colour="#64ca8d") + geom_point(colour="#63b3ed") + \
					   labs(title="${symbol.symbol} close price") + \
					   xlab("hour") + \
					   ylab("close price") + \
					   scale_x_continuous(breaks=seq(0,48,by=2)) + $theme_str') ?
       
	    r_out.writeln('hours <- ggplot(data=dataset,aes(y=hour_ratio,x=index)) + \
					   geom_line(colour="#64ca8d") + geom_point(colour="#63b3ed") + \
					   labs(title="${symbol.symbol} hour-over-hour %") + \
					   xlab("hour") + \
					   ylab("ratio") + \
					   geom_hline(yintercept=1.00,color="red",linetype="dashed") + \
					   scale_y_continuous(breaks=seq(-5,5,by=0.01)) + \
					   scale_x_continuous(breaks=seq(0,48,by=2)) + $theme_str') ?
		
		r_out.writeln('cums <- ggplot(data=dataset,aes(y=cum_ratio,x=index)) + \
		               geom_line(colour="#64ca8d") + geom_point(colour="#63b3ed") + \
					   labs(title="${symbol.symbol} 48 hour cumulative %") + \
					   xlab("hour") + \
					   ylab("cumulative %") + \
					   geom_hline(yintercept=1.00,color="red",linetype="dashed") + \
					   scale_y_continuous(breaks=seq(${lowest_ratio-0.2:0.1f},${highest_ratio+0.2:0.1f},by=0.05),limits=c(${lowest_ratio-.05:0.1f},${highest_ratio+0.06:0.01f}),labels=scaleFUN) + \
					   scale_x_continuous(breaks=seq(0,48,by=2)) + \
					   $theme_str') ?
		r_out.writeln('p <- grid.arrange(closing,cums,hours,ncol=3)') ?
		r_out.writeln('ggsave(plot=p,filename="${symbol.symbol}.png",width=21,height=7)') ?
		r_out.writeln('imgset <- image_read("${symbol.symbol}.png")') ?
		r_out.writeln('imset_scaled <- image_scale(imgset,"1500")') ?
		r_out.writeln('image_write(imset_scaled, path = "${symbol.symbol}.png", format = "png", quality = 75)') ?
		r_out.close()
	}
	println("[DONE]")

	println("Executing R script....  ")
	mut t := []thread{}
	mut idx := 0
	mut thread_c := 0
	max_threads := 4
	thread_batches := symbols.len/max_threads
	mut thread_batches_comp := 0
	
	for idx < symbols.len
	//for false
	{
		t << go execute_r_script("${symbols[idx].symbol}.r")
		
		for thread_c < max_threads
		{
			// Ensure not out of bounds....
			if idx+thread_c+1 < symbols.len
			{
				t << go execute_r_script("${symbols[idx+thread_c+1].symbol}.r")
			}
			thread_c++
		}
		
		t.wait()
		t.clear()
		thread_c=0
		idx+=max_threads
		thread_batches_comp++

		print("\e[1A") // Move cursor up one row.
		print("\e[2K") // Erase entire current line.
		println("Executing R script....  [$thread_batches_comp of $thread_batches]")
	}
	print("\e[1A") // Move cursor up one row.
	print("\e[2K") // Erase entire current line.
	println("Executing R script....  [DONE]")

	print("Generating HTML.......  ")
	mut html_out := os.create("index.html") ? 
	html_out.writeln('<!DOCTYPE html>') ?
	html_out.writeln('<html class="no-js" lang="en">') ?
	html_out.writeln('<head>') ?
	html_out.writeln('<meta http-equiv="content-type" content="text/html; charset=UTF-8">') ?
	html_out.writeln('<title>1point</title>') ?
	html_out.writeln('<meta name="description" content="1point is a free analytics tool for Binance Futures prices.">
    <meta name="keywords" content="binance, futures, trading">
    <meta name="viewport" content="width=device-width">') ?
	html_out.writeln('<body style="background:#1a202c;">') ?
	html_out.writeln('<style>h1{padding-top: 5px; color:#4fd1c5; font-size: 25px;}</style>') ?
	html_out.writeln('<style>h2{color:#ffffff; font-size: 15px;}</style>') ?
	html_out.writeln('<style>a:link{color:hotpink}a:visited{color:hotpink}a:hover{color:gold}</style>') ?
	html_out.writeln('<style>hrtext{color:#63b3ed; font-size: 15px;}</style>') ?
	html_out.writeln('<style>outlay{color:#64ca8d; font-size: 15px;}</style>') ?
	html_out.writeln('</head>') ?
	html_out.writeln('<pre style="color:honeydew">

 ██╗██████╗  ██████╗ ██╗███╗   ██╗████████╗ ██████╗ ███╗   ██╗███████╗
 ███║██╔══██╗██╔═══██╗██║████╗  ██║╚══██╔══╝██╔═══██╗████╗  ██║██╔════╝
 ╚██║██████╔╝██║   ██║██║██╔██╗ ██║   ██║   ██║   ██║██╔██╗ ██║█████╗  
  ██║██╔═══╝ ██║   ██║██║██║╚██╗██║   ██║   ██║   ██║██║╚██╗██║██╔══╝  
  ██║██║     ╚██████╔╝██║██║ ╚████║   ██║██╗╚██████╔╝██║ ╚████║███████╗
  ╚═╝╚═╝      ╚═════╝ ╚═╝╚═╝  ╚═══╝   ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝

</pre>')?
	html_out.writeln('<updated style="color:honeydew">UTC Refresh: ${time.utc()}<updated>') ?
	html_out.writeln('<a name="top"></a>') ?

	map_lots := get_lots()

    for entry in ratios
	{
		lot_info := map_lots[entry.pair]
		mut inc_purch_usdt := 0.0

		if lot_info.min_qty.len > 0 && lot_info.step_size.len > 0 && lot_info.curr_price.len >0
		{
			inc_purch_usdt = lot_info.step_size.f32()* lot_info.curr_price.f32()
		}

		html_out.writeln('<a name="${entry.pair}"><h1>${entry.pair} <a href="#top" style="font-size: 13px">Top</a>  <a href="#bottom" style="font-size: 13px">Bottom</a>  <a href="#${entry.pair}" style="font-size: 13px">#</a>  <a href="https://www.binance.com/en/futures/${entry.pair}" target="_blank" rel="noopener noreferrer" style="font-size: 13px">Binance</a></h1></a>') ?
		html_out.writeln('<h2><outlay>Outlay Increments</outlay>  $${inc_purch_usdt:0.2f}</h2>') ?
		html_out.writeln('<h2><hrtext>[1 HR]</hrtext>  ${stats[entry.pair].hr_1:0.1f}    <hrtext>[4 HR]</hrtext>  ${stats[entry.pair].hr_4:0.1f}    <hrtext>[8 HR]</hrtext>  ${stats[entry.pair].hr_8:0.1f}    <hrtext>[12 HR]</hrtext>  ${stats[entry.pair].hr_12:0.1f}    <hrtext>[24 HR]</hrtext>  ${stats[entry.pair].hr_24:0.1f}</h2>') ?
		html_out.writeln('<br>') ?
		html_out.writeln('<img src="${entry.pair}.png" alt="$entry.pair">') ?
		html_out.writeln('<br>') ?
	}

	html_out.writeln('<a name="bottom"></a>') ?
	html_out.writeln('<br><br><footer style="color:honeydew">Generated on Debian 11 x64 (bullseye), using V and R programming languages.<footer>') ?
	html_out.writeln('</body>') ?
	html_out.writeln('</html>') ?
	html_out.close()
	println("[DONE]")

	print("Cleaning up...........  ")
	os.execute("rm *.txt")
	os.execute("rm *.r")
	os.execute("rm Rplots.pdf")
	println("[DONE]")
}

fn get_lots() map[string]Lotstep
{
	mut ret_lot := map[string]Lotstep{}

	symbols := binance.get_exchangeinfo().symbols
	prices := binance.get_prices()

	// create map of prices
	mut price_map := map[string]string{}
	for price in prices
	{
		price_map[price.symbol] = price.price
	}

	for symbol in symbols
	{
		mut a_lot := Lotstep{}

		filters_arr := symbol.filters

		for filter in filters_arr
		{
			if compare_strings("LOT_SIZE",filter.filter_type) == 0
			{
				a_lot.min_qty = filter.min_qty
				a_lot.step_size = filter.step_size

			}
			if compare_strings("PRICE_FILTER",filter.filter_type) == 0
			{
				a_lot.min_price = filter.min_price
			}
		}
		a_lot.curr_price = price_map[symbol.symbol]
		ret_lot[symbol.symbol] = a_lot // Assign to map
	}

	return ret_lot
}

struct Stats
{
	mut:
		hr_1 f64
		hr_4 f64
		hr_6 f64
		hr_8 f64
		hr_12 f64
		hr_24 f64
		hr_48 f64
		var_1 f64
		var_4 f64
		var_6 f64
		var_8 f64
		var_12 f64
		var_24 f64
}

struct Lotstep 
{
	mut:
		min_price string
		min_qty string
		step_size string
		curr_price string
}

fn execute_r_script(script string)
{
	os.execute("Rscript $script")
}

struct Ratio
{
	mut:
	pair string
	ratio f64
}