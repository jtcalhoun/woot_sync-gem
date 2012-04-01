#  Copyright 2012 Taco Stadium LLC. All rights reserved.
#
#  All information contained herein, including documentation and any related
#  computer programs, is confidential, proprietary, and protected by trade
#  secret or copyright law. Use, reproduction, modification or transmission in
#  whole or in part in any form or by any means is prohibited without prior
#  written consent of Taco Stadium LLC.

this.WootSync = ((WootSync, $) ->
  ajaxSettings  =
    apiHost:  "https://wootspy.herokuapp.com/",
    siteHost: "http://wootspy.com",
    clientId: undefined

  $.extend WootSync,
    ajax: (path = "", options = {}) ->
      $.ajax $.extend options,
        url: ajaxSettings.apiHost + path,
        data: ($.extend {}, {client_id: ajaxSettings.clientId}, options.data ? {})

    ajaxSetup: (settings = {}) ->
      ajaxSettings = $.extend settings, ajaxSettings
      return this

    getJSON: (path, data) ->
      return @ajax path,
        dataType: "json",
        data:     data

  return WootSync
) WootSync ? {}, jQuery
