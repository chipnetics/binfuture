# Binance Futures CLI Trading

A repository of small utilities that will help in trading futures on the Binance brokerage platform, using command line interface tools.

# Project Motivation

Futures trading in cryptocurrency is fast-paced; especially when trading with leverage.  The market, as any experienced trader knows, is highly volatile and can swing several percentage points in minutes.  Trying to manage a position using the Binance software GUI, or worse -*their website*- is a serious disadvantage for trading.

This tools aim to make command-line trading and position monitoring as easy as possible, while minimizing the risk of mis-managing a long or short position.

*NB: I am __not responsible for any financial losses__ resulting from your usage of these tools.  This is strictly a hobby for myself as it's a great way to discover many programming language facilities such as API calls, JSON handling, data structures, and so forth. __If you have any doubts, please avoid trading entirely__.  Coins are deflationary, such that wealth accumulates only for early-stakers while long-tail people provide all the liquidity.  Crypto is highly evangelized by early-stakers to ensure more fools jump on the long-tail so they can continue to be liquidated. Nonetheless, there is opportunity for the occasional profits while having some fun in this fad.*

# Pre-Compiled Binaries

There are no pre-compiled binaries for two reasons:
* **In `src/binance/binance.v` you must replace api_key, and sec_key with your own keys**
* Shake out those users who are beyond their depth, yet are dabbling in high risk trading (sorry!)

_Goes without saying, when you compile your binary with you personal keys, be sure in Binance that you allow your key access to only trade from your IP address; otherwise anyone who has your executable can trade!_ =]

# Compiling from Source

Utilities are written in the V programming language and will compile under Windows, Linux, and MacOS.

V is syntactically similar to Go, while equally fast as C.  You can read about V [here](https://vlang.io/).

Each utility is its own .v file, so after installing the [latest V compiler](https://github.com/vlang/v/releases/), it's as easy as executing the below.  _Be sure that the V compiler root directory is part of your PATH environment._

```
git clone https://github.com/chipnetics/binfuture
cd src
v -prod binfuture.v
```
Alternatively, if you don't have git installed:

1. Download the bundled source [here](https://github.com/chipnetics/binfuture/archive/refs/heads/main.zip)
2. Unzip to a local directory
3. Navigate to src directory and run the **compile** arguments as I've detailed further down.

Please see the [V language documentation](https://github.com/vlang/v/blob/master/doc/docs.md) for further help if required.

# Windows Command Line Arguments

For Windows users, if you want to pass optional command line arguments to an executable:

1. Navigate to the directory of the utility.
2. In Windows Explorer type 'cmd' into the path navigation bar.
3. Type the name of the exe along with the optional argument (i.e. `binfuture.exe --help` ).

*** 

# Binance Utilities

## Bin Future (src/binfuture.v)
> Execute Binance Future trading from the command line (CLI).

**Compile:** `v -prod binfuture.v`

**Binary:** binfuture.exe (Windows) | binfuture (Linux)


**Command Line Arguments** 

```
Options:
  -s, --short <string>      short trading-pair [non-interactive mode]
  -l, --long <string>       long trading-pair [non-interactive mode]
  -p, --pair <string>       trading-pair [interactive mode]
  -d, --stoploss <string>   stop loss (as %)
  -u, --takeprofit <string>
                            take profit (as %)
  -x, --leverage <int>      leverage multiplier [default:1]
  -c, --spend <int>         max spend
  -i, --interactive         interactive mode
  -h, --help                display this help and exit
  --version                 output version information and exit
```

## Sample usage for staging a new trade

`./binfuture -p HNTUSDT -d 5 -u 1 -x 1 -i -c 100`

Flag breakdown:

* `[-p]` Prepare for a position in HNTUSDT trading pair
* `[-d]` Close the position if down 5%, or 
* `[-u]` Close the position if up 1% (whichever comes first)
* `[-x]` Set a leverage of 1x
* `[-i]` Interactive mode (you will enter long or short command when ready)
* `[-c]` Spend a maximum of 100 USDT

When executed you will get something like below (with your actual balances, of course).

```
[Leverage]	            1
[Margin Type]	        ISOLATED
[BNB Wallet Balance]	250.00

[USDT Wallet Balance]	500.00
[USDT Margin Balance]	500.00
[SPEND AMT]	            100.00
[CP]		            18.953
[MAX QTY]	            5

Execute command (h for help):
```
The program will automatically calculate the maximum quantity your imposed limit of $100 USDT can purchase, based on the step-size that particular trading pair allows.  For instance, some trading pairs only allow whole number quantities (1,2,3,4,..) while others allow for 1 to 8 decimals of precision.

Note, if you went with a leverage greater than 1 (like 5x), naturally your maximum quantity will scale appropriately as you have more purchasing power.

## Entering a short or long position

Typing h, as indicated above, will give menu options:

```
Execute command (h for help):h
[l] go long
[s] go short
```
Monitoring the price movement for your trading pair on Binance (or perhaps some ML/AI algo you have), when you see the opportunity arise on where you want to enter a short or a long, typing `l` or `s` at that moment in time will execute the trade immediately.  Confirmations will be shown and a real-time update of your PNL (profit and loss) will be echoed to stdout.

Since there is both a take profit and a stop loss position in this example, two additonal orders will be placed.  

In the case if you went long there will be:
* Buy position for your long.
* Sell order for your stop loss, and,
* Sell order for your take profit.  

Conversely, if you went short; there will be:
* Sell position for your short.
* Buy order for your stop loss, and, 
* Buy order for your take profit.

## Built in OCO (one cancels the other)
The utility is unique in that if you take-profit or stop-loss is triggered, it will automatically cancel the other open order (called OCO - one cancels other).  This is a natively built in feature in Spot trading on Binance; but does not exist in Futures trading by default.  However this tool acts as a watchdog, and will cancel the other order if one closes.

## Close position

If you decide to exit your position early (that is, not wait for a take profit or stop loss trigger), you can type `c` and hit enter to close your position.  The open stop-loss and take-profit orders will be cancelled; and your PNL will be realized.

--------

## Bin Prob (src/binprob.v)

> Calculates the probability of closing a position in various windows of time.  This tool will select a random market entry point in the specified historical window of time (doing so X number of times), and tracking how likely it takes to settle with take profit or stop loss trigger, or be left unresolved, in each period of time.

**Compile:** `v -prod binprob.v`

**Binary:** binfuture.exe (Windows) | binfuture (Linux)

**Command Line Arguments** 

```
Options:
  -s, --short               short trading-pair
  -l, --long                long trading-pair
  -p, --pair <string>       trading-pair
  -m, --minutes <int>       number of minutes [max 1000]
  -i, --iterations <int>    number of iterations
  -d, --stoploss <string>   stop loss (as %)
  -u, --takeprofit <string> take profit (as %)
  -h, --help                display this help and exit
  --version                 output version information and exit
```
## Sample usage 

`./binprob -u 0.25 -d 8 -l -p GALAUSDT -m 600 -i 50000`

Flag breakdown:

* `[-l]` Calculate outcomes of going long
* `[-p]` Using trading pair GALAUSDT
* `[-u]` With a take profit of 0.25%
* `[-d]` With a stop loss of 8% 
* `[-m]` Using the last 600 minutes (10 hours) of data
* `[-i]` Performing 50,000 iterations

## Sample output and how to interpret

```
1	40213	0.80	0.80
2	2992	0.06	0.86
3	1704	0.03	0.90
4	1320	0.03	0.92
5	1785	0.04	0.96
6	886	    0.02	0.98
7	15	    0.00	0.98
100	1085	0.02	1.00
```
This output indicates:
* 80% of the simulations triggered take-profit in the first hour
* 6% of the simulations triggered take-profit in the second hour (cumulative 86%)
* 3% of the simulations triggered take-profit in the third hour (cumulative 90%)
* _(and so forth...)_
* 99 and 100 are reserved integers to indicate Stop Loss, and Unresolved (respectively)
* In this example there was no stop-loss events triggered _(event 99)_
* 2% of simulations were left unresolved (no stop-loss or take-profit, yet) _(event 100)_

--------

## Bin Graph (src/bingraph.v)

> Generates a single HTML page of all the Binance Future trading pairs and some unique graphing perspectives that better visualize the magnitude of growth or loss such that long or short positions can be intelligently undertaken.

> This tool is used to generate the graphs seen at https://www.1point.one - which presently runs the top of every hour on a CRON job in Debian.

**Dependancies**

* R statistical package software
* Must have a folder named 'symbols' in the same directory as executable.

**Compile:** `v -prod bingraph.v`

**Binary:** bingraph.exe (Windows) | bingraph (Linux)

**Command Line Arguments** 

None

## Sample usage 

`./bingraph`

## Sample output

The 'symbols' folder will have a separate image for every trading pair graph, and a index.html file.

Visit https://www.1point.one for what the output looks like!

______

## Contributions, PR, Roadmap

Contributions and pull requests are welcome and encouraged.  Further development by myself will be fairly minimal and not follow any predictable trajectory - just like crypto. =]

