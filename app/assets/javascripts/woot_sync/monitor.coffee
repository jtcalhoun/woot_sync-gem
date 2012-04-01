#  Copyright 2012 Taco Stadium LLC. All rights reserved.
#
#  All information contained herein, including documentation and any related
#  computer programs, is confidential, proprietary, and protected by trade
#  secret or copyright law. Use, reproduction, modification or transmission in
#  whole or in part in any form or by any means is prohibited without prior
#  written consent of Taco Stadium LLC.

this.WootSync = ((WootSync, $) ->
  interval     = 60000 * 2 #minutes
  deferred     = undefined
  lastChange   = undefined
  lastResponse = undefined

  execute = ->
    if deferred and deferred.state() is "pending"
      WootSync
        .getJSON("/sales.json", if lastResponse then {since: lastResponse.toISOString()} else undefined)
        .always (sales, status) =>
          changed = {}

          `switch (status) {
            case "success":
              lastChange = new Date();
            case "notmodified":
              lastResponse = new Date();
              $.each($.makeArray(sales), function (index, sale) {
                if (!$.isEmptyObject(sale)) {
                  changed[sale.shop.name] = $.extend(true, {
                    shop: {
                      index: index
                    }
                  }, sale);
                }
              });
            default:
              deferred.notify(changed, status)
              setTimeout(execute, interval);
              break;
          }`

          return

  WootSync.monitor = ->
    this.monitor.start()

  $.extend WootSync.monitor,
    lastChange: ->
      lastChange

    lastResponse: ->
      lastResponse

    start: ->
      unless deferred and deferred.state() is "pending"
        deferred = $.Deferred()

      execute()

      deferred.promise()

    stop: ->
      deferred.resolve()

  return WootSync
) WootSync ? {}, jQuery
