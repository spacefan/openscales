package org.openscales.core.handler.mouse
{
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.net.URLLoader;
	
	import org.openscales.core.Map;
	import org.openscales.basetypes.Pixel;
	import org.openscales.core.events.GetFeatureInfoEvent;
	import org.openscales.core.handler.Handler;
	import org.openscales.core.layer.Layer;
	import org.openscales.core.layer.ogc.WMS;
	import org.openscales.core.layer.params.ogc.WMSGetFeatureInfoParams;
	import org.openscales.core.layer.params.ogc.WMSParams;
	import org.openscales.core.request.XMLRequest;
	
	/**
	 * Handler allowing to get information about a WMS feature when we click on it.
	 */
	public class WMSGetFeatureInfo extends Handler
	{
	
		private var _clickHandler:ClickHandler;
		private var _format:String;
		private var _maxFeatures:Number;
		private var _url:String;
		private var _layers:String;
		private var _request:XMLRequest;
		private var _srs:String;
    	  	
    	public function WMSGetFeatureInfo(target:Map = null, active:Boolean = false){
			super(target,active);
			_format = "application/vnd.ogc.gml";
			_maxFeatures = 10;
		}
		
		/**
		 * Get the existing map
		 * 
		 * @param map
		 */
		override public function set map(map:Map):void {
			super.map = map;
			_clickHandler = new ClickHandler(map, true);
			_clickHandler.click = this.getInfoForClick;
		}
		
		/**
		 * Set the existing format
		 * 
		 * @param format
		 */
		public function set format(format:String):void {
			_format = format;
		}
		
		/**
		 * Set the existing maxFeatures
		 * 
		 * @param maxFeatures
		 */
		public function set maxFeatures(maxFeatures:Number):void {
			_maxFeatures = maxFeatures;
		}
		
		public function set url(url:String):void {
			_url = url;
		}
		
		public function set layers(layers:String):void {
			_layers = layers;
		}
		
		public function set srs(srs:String):void {
			_srs = srs;
		}
		
		override public function set active(value:Boolean):void
		{
        	super.active = value;
            _clickHandler.active = value;
        } 
		
		private function getInfoForClick(p:Pixel):void {
			// get layers and styles
			var layerNames:String = _layers;
			var layerStyles:String = null;
			var theURL:String = _url;
			if (_layers == null) {
				var layers:Vector.<Layer> = map.layers;
				for (var i:Number = 0; i < layers.length; i++) {
					if (!layers[i].visible) continue;
					if (!(layers[i] is WMS)) continue;
					if (theURL == null) theURL = (layers[i] as WMS).url;
					if (theURL != (layers[i] as WMS).url) continue;
					var params:WMSParams = (layers[i] as WMS).params as WMSParams;
					if (layerNames == null) layerNames = "" else layerNames + ",";
					layerNames = layerNames + params.layers;
					if (layerStyles == null) layerStyles = "" else layerStyles + ",";
					if (params.styles != null) layerStyles = layerStyles + params.styles;
				}
			}
			
			// setup params for call
			var infoParams:WMSGetFeatureInfoParams = new WMSGetFeatureInfoParams(layerNames, _format, layerStyles);
			infoParams.bbox = this.map.extent.boundsToString();
			if (_srs == null)
				infoParams.srs = this.map.baseLayer.projection.srsCode;
			else
				infoParams.srs = _srs;
            infoParams.maxFeatures = _maxFeatures;
            var point:Point = this.map.globalToLocal(new Point(p.x,p.y)); 
            infoParams.x = point.x; 
            infoParams.y = point.y;
            infoParams.height = this.map.height;
            infoParams.width = this.map.width;
			
			// request data
			if(_request) {
				_request.destroy();
			}
			_request = new XMLRequest(theURL + "?" + infoParams.toGETString(), this.handleResponse);
			_request.proxy = map.proxy;
			//_request.security = null; //FixMe: should the security be managed here ?
			_request.send();
		}
		
		private function handleResponse(event:Event):void {
			var loader:URLLoader = event.target as URLLoader;
			this.map.dispatchEvent(new GetFeatureInfoEvent(GetFeatureInfoEvent.GET_FEATURE_INFO_DATA, loader.data));
		}
	}
}