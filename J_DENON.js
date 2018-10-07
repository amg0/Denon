//# sourceURL=J_DENON.js
// This program is free software: you can redistribute it and/or modify
// it under the condition that it is for private or home useage and 
// this whole comment is reproduced in the source code file.
// Commercial utilisation is not authorized without the appropriate
// written agreement from amg0 / alexis . mermet @ gmail . com
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

//-------------------------------------------------------------
// DENON  Plugin javascript Tabs
//-------------------------------------------------------------

var myapi = window.api || null
var DENON = (function(api,$) {
	
	var DENON_Svs = 'urn:upnp-org:serviceId:altdenon1';
	var splits = jQuery.fn.jquery.split(".");
	var ui5 = (splits[0]=="1" && splits[1]<="5");

	function isNullOrEmpty(value) {
		return (value == null || value.length === 0);	// undefined == null also
	};
	
	function format(str)
	{
	   var content = str;
	   for (var i=1; i < arguments.length; i++)
	   {
			var replacement = new RegExp('\\{' + (i-1) + '\\}', 'g');	// regex requires \ and assignment into string requires \\,
			// if (jQuery.type(arguments[i]) === "string")
				// arguments[i] = arguments[i].replace(/\$/g,'$');
			content = content.replace(replacement, arguments[i]);  
	   }
	   return content;
	};
	
	//-------------------------------------------------------------
	// Device TAB : Settings
	//-------------------------------------------------------------	

	// <input type="text" class="form-control" id="denon-ipaddr" placeholder="ip address" required=""  pattern="((^|\.)((25[0-5])|(2[0-4]\d)|(1\d\d)|([1-9]?\d))){4}$" value="" >	\
	function DENON_Settings(deviceID) {
		var ip_address = jsonp.ud.devices[DENON.findDeviceIdx(deviceID)].ip;
		var html =
		'                                                           \
		  <div id="denon-settings">                                           \
			<form novalidate action="javascript:void(0);" class="row" id="denon-settings-form">                        \
				<div class="form-group col-6 col-xs-6">																	\
					<label for="denon-ipaddr">IP Addr</label>		\
					<input type="text" class="form-control" id="denon-ipaddr" placeholder="ip address" required=""  value="" >	\
				</div>																										\
				<div class="form-group col-6 col-xs-6">																	\
				</div>																										\
				<button id="denon-submit" type="submit" class="btn btn-default">Submit</button>	\
			</form>                                                 \
		  </div>                                                    \
		'		// api.setCpanelContent(html);
		set_panel_html(html);
		jQuery( "#denon-ipaddr" ).val(ip_address);
		
		function _onSave(event) {
			var form = jQuery(this).closest("form")[0]
			var bValid = form.checkValidity()
			if (bValid === false) {
				event.preventDefault();
				event.stopPropagation();
				alert("The form has some invalid values")
			} else {
				var ip = jQuery( "#denon-ipaddr" ).val();
				if (DENON.goodip(ip)) {
					DENON.saveVar(deviceID,  null, "ip", ip, false)
					alert('changes are saved')
				} else {
					jQuery( "#denon-ipaddr" ).addClass("is-invalid").removeClass("is-valid")
					alert('invalid ip address')
				}
			}
			form.classList.add('was-validated');
			return false;
		}		
		jQuery( "#denon-settings-form" ).on("submit", _onSave)
	};
	
	var myModule = {
		DENON_Svs 	: DENON_Svs,
		format		: format,
		Settings 	: DENON_Settings,
		
		//-------------------------------------------------------------
		// Helper functions to build URLs to call VERA code from JS
		//-------------------------------------------------------------

		buildReloadUrl : function() {
			var urlHead = '' + data_request_url + 'id=reload';
			return urlHead;
		},
		
		buildAttributeSetUrl : function( deviceID, varName, varValue){
			var urlHead = '' + data_request_url + 'id=variableset&DeviceNum='+deviceID+'&Variable='+varName+'&Value='+varValue;
			return urlHead;
		},

		buildUPnPActionUrl : function(deviceID,service,action,params)
		{
			var urlHead = data_request_url +'id=action&output_format=json&DeviceNum='+deviceID+'&serviceId='+service+'&action='+action;//'&newTargetValue=1';
			if (params != undefined) {
				jQuery.each(params, function(index,value) {
					urlHead = urlHead+"&"+index+"="+value;
				});
			}
			return urlHead;
		},

		buildHandlerUrl: function(deviceID,command,params)
		{
			//http://192.168.1.5:3480/data_request?id=lr_IPhone_Handler
			params = params || []
			var urlHead = data_request_url +'id=lr_DENON_Handler&command='+command+'&DeviceNum='+deviceID;
			jQuery.each(params, function(index,value) {
				urlHead = urlHead+"&"+index+"="+encodeURIComponent(value);
			});
			return encodeURI(urlHead);
		},

		//-------------------------------------------------------------
		// Variable saving 
		//-------------------------------------------------------------
		saveVar : function(deviceID,  service, varName, varVal, reload) {
			if (service) {
				set_device_state(deviceID, service, varName, varVal, 0);	// lost in case of luup restart
			} else {
				jQuery.get( this.buildAttributeSetUrl( deviceID, varName, varVal) );
			}
			if (reload==true) {
				jQuery.get(this.buildReloadUrl())
			}
		},
		save : function(deviceID, service, varName, varVal, func, reload) {
			// reload is optional parameter and defaulted to false
			if (typeof reload === "undefined" || reload === null) { 
				reload = false; 
			}

			if ((!func) || func(varVal)) {
				this.saveVar(deviceID,  service, varName, varVal, reload)
				jQuery('#DENON-' + varName).css('color', 'black');
				return true;
			} else {
				jQuery('#DENON-' + varName).css('color', 'red');
				alert(varName+':'+varVal+' is not correct');
			}
			return false;
		},
		
		get_device_state_async: function(deviceID,  service, varName, func ) {
			// var dcu = data_request_url.sub("/data_request","")	// for UI5 as well as UI7
			var url = data_request_url+'id=variableget&DeviceNum='+deviceID+'&serviceId='+service+'&Variable='+varName;	
			jQuery.get(url)
			.done( function(data) {
				if (jQuery.isFunction(func)) {
					(func)(data)
				}
			})
		},
		
		findDeviceIdx:function(deviceID) 
		{
			//jsonp.ud.devices
			for(var i=0; i<jsonp.ud.devices.length; i++) {
				if (jsonp.ud.devices[i].id == deviceID) 
					return i;
			}
			return null;
		},
		
		goodip : function(ip) {
			// @duiffie contribution
			var reg = new RegExp('^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:\\d{1,5})?$', 'i');
			return(reg.test(ip));
		},
		
		array2Table : function(arr,idcolumn,viscols,caption,cls,htmlid,bResponsive) {
			var html="";
			var idcolumn = idcolumn || 'id';
			var viscols = viscols || [idcolumn];
			var responsive = ((bResponsive==null) || (bResponsive==true)) ? 'table-responsive-OFF' : ''

			if ( (arr) && (jQuery.isArray(arr) && (arr.length>0)) ) {
				var display_order = [];
				var keys= Object.keys(arr[0]);
				jQuery.each(viscols,function(k,v) {
					if (jQuery.inArray(v,keys)!=-1) {
						display_order.push(v);
					}
				});
				jQuery.each(keys,function(k,v) {
					if (jQuery.inArray(v,viscols)==-1) {
						display_order.push(v);
					}
				});

				var bFirst=true;
				html+= DENON.format("<table id='{1}' class='table {2} table-sm table-hover table-striped {0}'>",cls || '', htmlid || 'altui-grid' , responsive );
				if (caption)
					html += DENON.format("<caption>{0}</caption>",caption)
				jQuery.each(arr, function(idx,obj) {
					if (bFirst) {
						html+="<thead>"
						html+="<tr>"
						jQuery.each(display_order,function(_k,k) {
							html+=DENON.format("<th style='text-transform: capitalize;' data-column-id='{0}' {1} {2}>",
								k,
								(k==idcolumn) ? "data-identifier='true'" : "",
								DENON.format("data-visible='{0}'", jQuery.inArray(k,viscols)!=-1 )
							)
							html+=k;
							html+="</th>"
						});
						html+="</tr>"
						html+="</thead>"
						html+="<tbody>"
						bFirst=false;
					}
					html+="<tr>"
					jQuery.each(display_order,function(_k,k) {
						html+="<td>"
						html+=(obj[k]!=undefined) ? obj[k] : '';
						html+="</td>"
					});
					html+="</tr>"
				});
				html+="</tbody>"
				html+="</table>";
			}
			else
				html +=DENON.format("<div>{0}</div>","No data to display")

			return html;		
		}
	}
	return myModule;
})(myapi ,jQuery)

	
//-------------------------------------------------------------
// Device TAB : Donate
//-------------------------------------------------------------	
function DENON_Settings (deviceID) {
	return DENON.Settings(deviceID)
}
		
function DENON_Donate(deviceID) {
	var htmlDonate='<p>Ce plugin est gratuit mais vous pouvez aider l\'auteur par une donation modique qui sera tres appréciée</p><p>This plugin is free but please consider supporting it by a very appreciated donation to the author.</p>';
	htmlDonate+='<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_blank"><input type="hidden" name="cmd" value="_donations"><input type="hidden" name="business" value="alexis.mermet@free.fr"><input type="hidden" name="lc" value="FR"><input type="hidden" name="item_name" value="Alexis Mermet"><input type="hidden" name="item_number" value="DENON"><input type="hidden" name="no_note" value="0"><input type="hidden" name="currency_code" value="EUR"><input type="hidden" name="bn" value="PP-DonationsBF:btn_donateCC_LG.gif:NonHostedGuest"><input type="image" src="https://www.paypalobjects.com/en_US/FR/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!"><img alt="" border="0" src="https://www.paypalobjects.com/fr_FR/i/scr/pixel.gif" width="1" height="1"></form>';
	var html = '<div>'+htmlDonate+'</div>';
	set_panel_html(html);
}

