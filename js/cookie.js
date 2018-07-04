<?php
	//if (isset($route_varso)) echo "<!-- $route_varso --!>";
	$js_files=array("mainfooter","other","scriptsitebar");
	if (!in_array($script_name, $js_files)) show_404();
	if ($script_name=="mainfooter") {
?>
        jQuery(function() {
            jQuery("#hyv-search").autocomplete({
                source: function( request, response ) {
                    var sqValue = [];
                    jQuery.ajax({
                        type: "POST",
                        url: "https://suggestqueries.google.com/complete/search?hl=en&ds=yt&client=youtube&hjson=t&cp=1",
                        dataType: 'jsonp',
                        data: jQuery.extend({
                            q: request.term
                        }, {  }),
                        success: function(data){
                            //console.log(data[1]);
                            obj = data[1];
                            jQuery.each( obj, function( key, value ) {
                                sqValue.push(value[0]);
                            });
                            response( sqValue);
                        }
                    });
                }
            });
        });

        var $obj = $('#hyv-search');
        $obj.change(function() {
            $('#hyv-yt-search').attr('action', '<? $link = x2(array("route" => "search/index"))->route->link; echo $link->href; ?>/' + $obj.prop('value').replace(/ /ig,'+'));
        });

        var pull = [
            '<?php echo $coocies_sub; ?>',
            '<?php echo $coocies_like; ?>',
            '<?php echo $coocies_wl; ?>',
            '<?php echo $coocies_pl; ?>',
            'cookies_dislike'
        ];
        var sep = '[o]';
        var exp = 1825;
        var pth = '/';
        var dmn = 'up-tube.com';

        // функция записывающая куки
        function writeCookie(name, $obj) {
            var val = $.cookie(name);
            var id  = $obj.attr('id');
            var res = null;
            var cnt = 0;
            if(val != null) {
                var map = val.split(sep);
                var i   = $.inArray(id, map);

                if($obj.prop('checked')) {
                    if(i == -1) map.push(id);
                    cnt = 1;
                }
                else {
                    if(i > -1) map.splice(i, 1);
                    cnt = -1;
                }

                if(map.length > 0) res = map.join(sep);
                else $.removeCookie(name, {path: pth});
            }
            else
                if ($obj.prop('checked')) {
                    res = id;
                    cnt = 1;
                }
            if(cnt != 0) changeCounter(id, cnt);//console.log("1  "+cnt);
            if(res != null) {
                $.cookie(name, res, {
                    expires: exp,
                    path: pth,
                    //domain: dmn,
                    secure: false
                });
            }
        }

        //
        function switchCookie($obj_1, $obj_2) {
            writeCookie('<?php echo $coocies_like; ?>', $obj_1);
            writeCookie('cookies_dislike', $obj_2);
        }

        //
        function changeCounter(id, cnt) {
            var tag = $('#'+id+'+label>.counter');
            tag.text(parseInt(tag.html(), 10) + cnt);
        }

        // функция записывающая глобальные куки
        function writeGlobalCookie(what, there) {
            var name = '<?php echo $coocies_global; ?>';
            var val  = $.cookie(name);

            if(val != null) {
                var map = val.split('.');
                if(map.length >= 5) {
                    switch (what) {
                        case 'region': map[2] = there.toUpperCase(); break;
                        case   'lang': map[4] = there; break;
                        default: break;
                    }
                    $.cookie(name, map.join('.'), {
                        expires: exp,
                        path: pth,
                        //domain: dmn,
                        secure: false
                    });
                    window.location.reload(false);
                }
            }
        }

        // функция устанавливающая глобальные куки
        var name = '<?php echo $coocies_global; ?>';
        if($.cookie(name) == null) {
            $.cookie(name, [0,0,"<?php echo $regio['id'];?>",,"<?php echo x2()->hl;?>",0,0].join('.'), {
                expires: exp,
                path: pth,
                //domain: dmn,
                secure: false
            });
        }

        // функция сбрасывающая куки
        function deleteCookie(name) {
            $.removeCookie(name);
        }

        // восстанавление состояния по кукам
        for(var i in pull) {
            var val = $.cookie(pull[i]);
            if(val != null) {
                var map = val.split(sep);
                for(var j in map) {
                    $('#'+map[j]).prop('checked', true);
                    changeCounter(map[j], 1);
                }
            }
        }

    <?}
	  if ($script_name=="other"){
		  if (isset($_SERVER['HTTP_REFERER'])){
		    if (strpos($_SERVER['HTTP_REFERER'], x2()->domain)){
			    if (isset($main_v_yt_title) && isset($rel_v_yt_title)){
				    if (strpos($main_v_yt_title, "'")!==false) $main_v_yt_title = str_replace("'", "\\'", $main_v_yt_title);
				    if (strpos($rel_v_yt_title, "'")!==false) $rel_v_yt_title = str_replace("'", "\\'", $rel_v_yt_title);
	  ?>
	           document.getElementById("tit").innerHTML = '<?php echo $main_v_yt_title?>';
	           document.getElementById("tit_r").innerHTML = '<?php echo $rel_v_yt_title?>';
	<?
		       } else {
			       echo "";
		       }
		    } else {
			    echo "";
		      }
		  } else {
			  echo "";
		  }
	  }
	  if ($script_name=="scriptsitebar"){
		  if (isset($_SERVER['HTTP_REFERER'])){
		    if (strpos($_SERVER['HTTP_REFERER'], x2()->domain)){//document.getElementById("ad").innerHTML = '<div><div>'
	  ?>
	           
	<?
		    } else {
			    echo "";
		      }
		  } else {
			  echo "";
		  }
	  }
    ?>