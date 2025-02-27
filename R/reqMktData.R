.reqMktData <-
function (conn, Contract, 
          tickGenerics='100,101,104,106,165,221,225,236',
          snapshot = FALSE, tickerId = "1")
{
    if (!is.twsConnection(conn))
        stop("tws connection object required")

    if(!is.twsPlayback(conn)) {
      Contract <- as.twsContract(Contract)
      if(is.twsContract(Contract)) Contract <- list(Contract)
  
      for(n in 1:length(Contract)) {
        if (!is.twsContract(Contract[[n]]))
            stop("twsContract required")
      }
    } #else file <- ""
    con <- conn[[1]]
    if (!isOpen(con)) 
        stop("connection to TWS has been closed")
    VERSION <- "9"
 
    ticker_id <- as.character(tickerId)
    snapshot <- "0"

    if(inherits(con, 'sockconn')) {
      # write to TWS connection
      for(n in 1:length(Contract)) {
        if(Contract[[n]]$sectype=="BAG") {
          bag <- length(Contract[[n]]$comboleg)
          for(leg in 1:bag) {
          bag <- c(bag,Contract[[n]]$comboleg[[leg]]$conId,
                   Contract[[n]]$comboleg[[leg]]$ratio,
                   Contract[[n]]$comboleg[[leg]]$action,
                   Contract[[n]]$comboleg[[leg]]$exchange)
          }
        } else bag <- "0"
        signals <- c(.twsOutgoingMSG$REQ_MKT_DATA,
                     VERSION,
                     ticker_id,  # why?
                     Contract[[n]]$conId,
                     Contract[[n]]$symbol,
                     Contract[[n]]$sectype,
                     Contract[[n]]$expiry,
                     Contract[[n]]$strike, 
                     Contract[[n]]$right,
                     Contract[[n]]$multiplier,
                     Contract[[n]]$exch,
                     Contract[[n]]$primary, 
                     Contract[[n]]$currency,
                     Contract[[n]]$local,
                     bag,
                     tickGenerics,
                     snapshot)
    
        writeBin(signals, con) 
        ticker_id <- as.character(as.numeric(tickerId)+n)
      }
    }
    ticker_id # this needs to be a vector to be of any use.
}

reqMktData <-
function (conn, Contract, tickGenerics='100,101,104,106,165,221,225,236',
          snapshot = FALSE, tickerId = "1", timeStamp="%Y%m%d %H:%M:%OS",playback=1,
          file='', verbose=TRUE,
          eventWrapper=eWrapper(), CALLBACK=twsCALLBACK, ...)
{
    if (!is.twsConnection(conn))
        stop("tws connection object required")

    if(!is.twsPlayback(conn)) {
      Contract <- as.twsContract(Contract)
      if(is.twsContract(Contract)) Contract <- list(Contract)
  
      for(n in 1:length(Contract)) {
        if (!is.twsContract(Contract[[n]])) 
            stop("twsContract required")
      }
      
    } #else file <- ""

    con <- conn[[1]]
    if (!isOpen(con)) 
        stop("connection to TWS has been closed")

    cancelMktData <- function(con,tickerId) {
      # only cancel if this is an active socket connection,
      # not a playback
      if(inherits(con,'sockconn')) {
        for(i in 1:length(tickerId)) {
          writeBin(.twsOutgoingMSG$CANCEL_MKT_DATA,con)
          writeBin('2',con)
          writeBin(tickerId[i],con)
        }
      } else {
        # reset to beginning of file
        seek(con,0)
      }
    }

    if(is.null(CALLBACK))
      CALLBACK <- twsDEBUG

    snapshot <- ifelse(snapshot,"1","0")

    if(snapshot == '1' && missing(tickGenerics)) tickGenerics <- ''
  
    VERSION <- "163"
 
    fullSnapshot <- data.frame()
    symbols. <- NULL
    ticker_id <- as.character(tickerId)

    symbol.or.local <- function(x) {
      # used to find best name for id in output
      symbol <- x$symbol
      local  <- x$local
      if(local=="") {
        return(symbol)
      } else return(local)
    }

    if(inherits(con, 'sockconn')) {
      # write to TWS connection
      for(n in 1:length(Contract)) {
        if(Contract[[n]]$sectype=="BAG") {
          stop("BAG contract type not implemented for reqMktData")
          bag <- length(Contract[[n]]$comboleg)
          for(leg in 1:bag) {
          bag <- c(bag,Contract[[n]]$comboleg[[leg]]$conId,
                   Contract[[n]]$comboleg[[leg]]$ratio,
                   Contract[[n]]$comboleg[[leg]]$action,
                   Contract[[n]]$comboleg[[leg]]$exchange)
          }
        } else bag <- "0"
        signals <- c(.twsOutgoingMSG$REQ_MKT_DATA,
                     VERSION,
                     ticker_id,  # why?
                     Contract[[n]]$conId,
                     Contract[[n]]$symbol,
                     Contract[[n]]$sectype,
                     Contract[[n]]$expiry,
                     Contract[[n]]$strike, 
                     Contract[[n]]$right,
                     Contract[[n]]$multiplier,
                     Contract[[n]]$exch,
                     Contract[[n]]$primary, 
                     Contract[[n]]$currency,
                     Contract[[n]]$local,
                     if(is.null(Contract[[n]]$tradingClass)) "" else Contract[[n]]$tradingClass,
                     "0",
                     tickGenerics,
                     snapshot,
                     "")
    
        writeBin(signals, con) 
        if(snapshot == "1") {
          eventWrapper <- eWrapper.snapshot()
          while(1) {
            socketSelect(list(con), FALSE, NULL)
            curMsg <- readBin(con, character(), 1)
            processMsg(curMsg, con, eventWrapper, NULL, file, ...)
            if(curMsg == .twsIncomingMSG$TICK_SNAPSHOT_END) {
            fullSnapshot <- rbind(fullSnapshot, data.frame(
                                    lastTimeStamp=eventWrapper$get.Data("lastTimeStamp"),
                                    symbol=symbol.or.local(Contract[[n]]),
                                    #symbol=Contract[[n]]$symbol,
                                    bidSize=eventWrapper$get.Data("bidSize"),
                                    bidPrice=eventWrapper$get.Data("bidPrice"),
                                    askPrice=eventWrapper$get.Data("askPrice"),
                                    askSize=eventWrapper$get.Data("askSize"),
                                    lastPrice=eventWrapper$get.Data("lastPrice"),
                                    Volume=eventWrapper$get.Data("Volume"),
                                    Open=eventWrapper$get.Data("Open"),
                                    High=eventWrapper$get.Data("High"),
                                    Low=eventWrapper$get.Data("Low"),
                                    Close=eventWrapper$get.Data("Close")
                                   ))
            break
            }
          }
        if(n == length(Contract)) return(fullSnapshot)
        }
        ticker_id <- as.character(as.numeric(tickerId)+n)
        symbols. <- c(symbols., symbol.or.local(Contract[[n]]))
        #symbols. <- c(symbols., Contract[[n]]$symbol)
      }
    }
    #if(missing(eventWrapper)) {
      eventWrapper$assign.Data("symbols", symbols.)
      #eventWrapper$assign.Data("data", rep(list(rep(NA,8)),length(Contract)))
    #}


    if(!missing(CALLBACK) && is.na(list(CALLBACK))) {
      if(is.twsPlayback(conn)) {
        seek(conn[[1]],0)
        stop("CALLBACK=NA is not available for playback")
      }
      return(as.character(as.numeric(tickerId):length(Contract)))
    }
    if(snapshot=="0") {
      #on.exit(cancelMktData(con,as.character(as.numeric(tickerId):length(Contract))))
      on.exit(if(isOpen(con)) cancelMktData(con, as.character(as.numeric(tickerId):length(Contract))))
    }

    if(!is.list(file))
      file <- list(file)
    if(length(file) != length(Contract))
      file <- rep(file, length(Contract))
    CALLBACK(conn, eWrapper=eventWrapper, 
             timestamp=timeStamp, file=file,
             playback=playback, timeout=NULL, ...)

}

cancelMktData <- function(conn,tickerId) {
  if( !is.twsConnection(conn)) 
    stop("twsConnection object required")

  con <- conn[[1]]

  for(i in 1:length(tickerId)) {
    writeBin(.twsOutgoingMSG$CANCEL_MKT_DATA,con)
    writeBin('2',con)
    writeBin(tickerId[i],con)
  }
}

.reqMktData.vignette <-
function (conn, Contract, tickGenerics='100,101,104,106,165,221,225,236',
          snapshot = FALSE, tickerId = "1", timeStamp=TRUE,playback=1,
          file='', verbose=TRUE,
          eventTickPrice,eventTickSize,
          eventTickOption,eventTickGeneric,
          eventTickString,eventTickEFP,CALLBACK,...) 
{
    if (!is.twsConnection(conn))
        stop("tws connection object required")

    if(!is.twsPlayback(conn)) {
      if(inherits(Contract, "twsContract")) Contract <- list(Contract)
  
      for(n in 1:length(Contract)) {
        if (!inherits(Contract[[n]], "twsContract") )
            stop("twsContract required")
      }
    }

    con <- conn[[1]]
    if (!isOpen(con)) 
        stop("connection to TWS has been closed")

    cancelMktData <- function(con,tickerId) {
      # only cancel if this is an active socket connection,
      # not a playback
      if(inherits(con,'sockconn')) {
        for(i in 1:length(tickerId)) {
          writeBin(.twsOutgoingMSG$CANCEL_MKT_DATA,con)
          writeBin('1',con)
          writeBin(tickerId[i],con)
        }
      } else {
        # reset to beginning of file
        seek(con,0)
      }
    }

    if(!is.character(timeStamp) && timeStamp) {
      timeStamp <- "%Y%m%d %H:%M:%OS"
    } else {
      timeStamp <- NULL
    }
    # set up default event handlers, if
    # callback is not set
    if(missing(CALLBACK)) {
      if(missing(eventTickPrice))
        eventTickPrice   <- e_tick_price
      if(missing(eventTickSize))
        eventTickSize    <- e_tick_size
      if(missing(eventTickOption)) 
        eventTickOption  <- e_tick_option
      if(missing(eventTickGeneric)) 
        eventTickGeneric <- e_tick_generic
      if(missing(eventTickString)) 
        eventTickString  <- e_tick_string
      if(missing(eventTickEFP))
        eventTickEFP     <- e_tick_EFP
    } 
    else if(is.null(CALLBACK)) {
        eventTickPrice   <- NULL
        eventTickSize    <- NULL
        eventTickOption  <- NULL
        eventTickGeneric <- NULL
        eventTickString  <- NULL
        eventTickEFP     <- NULL
    }


    snapshot <- ifelse(snapshot,"1","0")

    if(snapshot == '1' && missing(tickGenerics)) tickGenerics <- ''
  
    VERSION <- "7"
 
    ticker_id <- as.character(tickerId)

    if(inherits(con, 'sockconn')) {
      # write to TWS connection
      for(n in 1:length(Contract)) {
        signals <- c(.twsOutgoingMSG$REQ_MKT_DATA,
                     VERSION,
                     ticker_id,
                     Contract[[n]]$symbol,
                     Contract[[n]]$sectype,
                     Contract[[n]]$expiry,
                     Contract[[n]]$strike, 
                     Contract[[n]]$right,
                     Contract[[n]]$multiplier,
                     Contract[[n]]$exch,
                     Contract[[n]]$primary, 
                     Contract[[n]]$currency,
                     Contract[[n]]$local,
                     tickGenerics,
                     snapshot)
    
         writeBin(signals, con) 
    #    for (i in 1:length(signals)) {
    #        writeBin(signals[i], con)
    #    }
        ticker_id <- as.character(as.numeric(tickerId)+n)
      }
      msg_expected_length <- NA
    } else {
      # reading from a file
      msg_expected_length <- as.numeric(readBin(con,character(), 1))
      #timeStamp <- NULL #disable erroneous R timestamps
    }

    if(!missing(CALLBACK) && is.na(list(CALLBACK))) {
      if(is.twsPlayback(conn)) {
        seek(conn[[1]],0)
        stop("CALLBACK=NA is not available for playback")
      }
      return(as.character(as.numeric(tickerId):length(Contract)))
    }
    on.exit(cancelMktData(con, as.character(as.numeric(tickerId):length(Contract))))

    waiting <- TRUE

    msg_length <- ifelse(is.twsPlayback(conn), 3, 1)
    msg_position <- 0 # where we are in the message - only relevant for playback
    sys.time <- NULL # used for timeStamp interpretation

#used for vignette counting only --- not in production code
VCOUNT <- 0

    if(missing(CALLBACK) || is.null(CALLBACK)) {
      while (waiting) {

        # read the msg header for each new message,
        # for standard connection to TWS this is the first
        # character string received. For playback the
        # actual message will be the 3rd (after the date and time
        # stamps).  

        curMsg <- readBin(con, character(), msg_length)

        if(!is.null(timeStamp)) {
          if(msg_length > 1) {
            last.time <- sys.time
            sys.time <- as.POSIXct(paste(curMsg[1:2],collapse=' '))
            if(!is.null(last.time)) {
              Sys.sleep((sys.time-last.time)*playback)
            } 
          } else sys.time <- Sys.time()
        } else sys.time <- NULL

        curMsg <- curMsg[msg_length] 

        msg_position <- msg_position + msg_length 

        if (length(curMsg) > 0) {
          if (curMsg == .twsIncomingMSG$ERR_MSG) {
              if (!errorHandler(con, verbose, OK = c(165, 300, 366, 2104,2106,2107))) {
                cat("\n")
                stop("Unable to complete market data request")
              }
              msg_position <- msg_position + 4
          }
          if (curMsg == .twsIncomingMSG$TICK_PRICE) {
              contents <- readBin(con, character(), 6)
              if(is.null(eventTickPrice)) {
                if (!is.null(timeStamp)) cat(as.character(sys.time),' ',file=file,append=TRUE)
                cat(curMsg,paste(contents),'\n',file=file, append=TRUE)
              } else eventTickPrice(curMsg,contents,sys.time,file)
              msg_position <- msg_position + 6
          }
          if (curMsg == .twsIncomingMSG$TICK_SIZE) {
              contents <- readBin(con, character(), 4)
              if(is.null(eventTickSize)) {
                if (!is.null(timeStamp)) cat(as.character(sys.time),' ',file=file,append=TRUE)
                cat(curMsg,paste(contents),'\n',file=file, append=TRUE)
              } else eventTickSize(curMsg,contents,sys.time,file)
              msg_position <- msg_position + 4
          }
          if (curMsg == .twsIncomingMSG$TICK_OPTION) {
              contents <- readBin(con, character(), 5)
              if(is.null(eventTickOption)) {
                if (!is.null(timeStamp)) cat(as.character(sys.time),' ',file=file,append=TRUE)
                cat(curMsg,paste(contents),'\n',file=file, append=TRUE)
              } else eventTickOption(curMsg,contents,sys.time,file)
              msg_position <- msg_position + 5
          }
          if (curMsg == .twsIncomingMSG$TICK_GENERIC) {
              contents <- readBin(con, character(), 4)
              if(is.null(eventTickGeneric)) {
                if (!is.null(timeStamp)) cat(as.character(sys.time),' ',file=file,append=TRUE)
                cat(curMsg,paste(contents),'\n',file=file, append=TRUE)
              } else eventTickGeneric(curMsg,contents,sys.time,file)
              msg_position <- msg_position + 4
          }
          if (curMsg == .twsIncomingMSG$TICK_STRING) {
              contents <- readBin(con, character(), 4)
              if(is.null(eventTickString)) {
                if (!is.null(timeStamp)) cat(as.character(sys.time),' ',file=file,append=TRUE)
                cat(curMsg,paste(contents),'\n',file=file, append=TRUE)
              } else eventTickString(curMsg,contents,sys.time,file)
              msg_position <- msg_position + 4
              if(snapshot == '1') 
                waiting <- FALSE
          }
          if (curMsg == .twsIncomingMSG$TICK_EFP) {
              contents <- readBin(con, character(), 13)
              if(is.null(eventTickEFP)) {
                if (!is.null(timeStamp)) cat(as.character(sys.time),' ',file=file,append=TRUE)
                cat(curMsg,paste(contents),'\n',file=file, append=TRUE)
              } else {
                cat('<efp> ')
                cat(curMsg,paste(contents),'\n')
              }
              msg_position <- msg_position + 13
          }
          flush.console()
          if(!is.na(msg_expected_length) && msg_position == msg_expected_length)
            waiting <- FALSE
        }
#vignette version only
VCOUNT <- VCOUNT + 1
if(VCOUNT == 20) waiting <- FALSE
      }
    } else CALLBACK(con,...)
}
