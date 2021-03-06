package org.openscales.core.layer {
	import flash.display.Sprite;
	
	import org.openscales.core.Map;
	import org.openscales.core.Trace;
	import org.openscales.basetypes.Bounds;
	import org.openscales.basetypes.LonLat;
	import org.openscales.basetypes.Pixel;
	import org.openscales.basetypes.Size;
	import org.openscales.core.events.LayerEvent;
	import org.openscales.core.events.MapEvent;
	import org.openscales.core.security.ISecurity;
	import org.openscales.core.security.events.SecurityEvent;
	import org.openscales.proj4as.Proj4as;
	import org.openscales.proj4as.ProjProjection;

	/**
	 * A Layer display image of vector datas on the map, usually loaded from a remote datasource.
	 * Unit of the baseLayer is hanging by the projection. To access : this.projection.projParams.units
	 *
	 * @author Bouiaw
	 */
	public class Layer extends Sprite {
		public static const DEFAULT_SRS_CODE:String = "EPSG:4326";

		public static function get DEFAULT_PROJECTION():ProjProjection {
			return new ProjProjection(DEFAULT_SRS_CODE);
		}

		public static function get DEFAULT_MAXEXTENT():Bounds {
			return new Bounds(-180, -90, 180, 90);
		}
		public static const DEFAULT_NOMINAL_RESOLUTION:Number = 1.40625;
		public static const RESOLUTION_TOLERANCE:Number = 0.000001;
		public static const DEFAULT_NUM_ZOOM_LEVELS:uint = 16;


		private var _isBaseLayer:Boolean = false;
		private var _isFixed:Boolean = false;
		private var _projection:ProjProjection = null;
		private var _resolutions:Array = null;
		private var _maxExtent:Bounds = null;
		private var _minZoomLevel:Number = NaN;
		private var _maxZoomLevel:Number = NaN;
		private var _proxy:String = null;
		private var _map:Map = null;
		private var _security:ISecurity = null;
		private var _loading:Boolean = false;
		private var _autoResolution:Boolean = true;
		protected var _imageSize:Size = null;

		/**
		 * Layer constructor
		 */
		public function Layer(name:String) {
			this.name = name;
			this.visible = true;
			this.isBaseLayer = false;
			this.doubleClickEnabled = true;
			this._projection = new ProjProjection(Layer.DEFAULT_SRS_CODE);
			this.generateResolutions();
		}

		public function generateResolutions(numZoomLevels:uint=Layer.DEFAULT_NUM_ZOOM_LEVELS, nominalResolution:Number=NaN):void {

			if (isNaN(nominalResolution)) {
				if (this.projection.srsCode == Layer.DEFAULT_SRS_CODE) {
					nominalResolution = Layer.DEFAULT_NOMINAL_RESOLUTION;
				} else {
					nominalResolution = Proj4as.unit_transform(new ProjProjection(Layer.DEFAULT_SRS_CODE), this.projection, Layer.DEFAULT_NOMINAL_RESOLUTION);
				}
			}
			// numZoomLevels must be strictly greater than zero
			if (numZoomLevels == 0) {
				numZoomLevels = 1;
			}
			// Generate default resolutions
			this._resolutions = new Array();
			this._resolutions.push(nominalResolution);
			var i:int = 1;
			for (i; i < numZoomLevels; ++i) {
				this._resolutions.push(this.resolutions[i - 1] / 2);
			}
			this._resolutions.sort(Array.NUMERIC | Array.DESCENDING);

			this._autoResolution = true;
		}

		public function destroy():void {
			this.removeEventListenerFromMap();
			this.map = null;
		}

		public function removeEventListenerFromMap():void {
			if (this.map != null) {
				map.removeEventListener(SecurityEvent.SECURITY_INITIALIZED, onSecurityInitialized);
				map.removeEventListener(MapEvent.MOVE_END, onMapMove);
				map.removeEventListener(MapEvent.ZOOM_END, onMapZoom);
				map.removeEventListener(MapEvent.RESIZE, onMapResize);
			}
		}

		public function onMapResize(e:MapEvent):void {
			if(this.visible) {
				this.redraw();
			}
		}

		/**
		 * Set the map where this layer is attached.
		 * Here we take care to bring over any of the necessary default properties from the map.
		 */
		public function set map(map:Map):void {
			if (this.map != null) {
				removeEventListenerFromMap();
			}

			this._map = map;

			if (this.map) {
				this.map.addEventListener(SecurityEvent.SECURITY_INITIALIZED, onSecurityInitialized);
				this.map.addEventListener(MapEvent.MOVE_END, onMapMove);
				this.map.addEventListener(MapEvent.ZOOM_END, onMapZoom);
				this.map.addEventListener(MapEvent.RESIZE, onMapResize);
				if (! this.maxExtent) {
					this.maxExtent = this.map.maxExtent;
				}
			}
		}
		
		public function onSecurityInitialized(e:SecurityEvent):void {
			this.redraw();
		}

		public function onMapMove(e:MapEvent):void {
			this.redraw(false);
		}

		public function onMapZoom(e:MapEvent):void {
			this.redraw();
		}

		public function get map():Map {
			return this._map;
		}

		/**
		 * A Bounds object which represents the lon/lat bounds of the current viewPort.
		 */
		public function get extent():Bounds {
			return this.map.extent;
		}

		public function getZoomForExtent(extent:Bounds):Number {
			var viewSize:Size = this.map.size;
			var idealResolution:Number = Math.max(extent.width / viewSize.w, extent.height / viewSize.h);
			return this.getZoomForResolution(idealResolution);
		}

		/**
		 * Return The index of the zoomLevel (entry in the resolutions array)
		 * that corresponds to the best fit resolution given the passed in
		 * value and the 'closest' specification.
		 */
		public function getZoomForResolution(resolution:Number):Number {
			if(resolution > this.resolutions[this.minZoomLevel]) {
				return this.minZoomLevel;
			}
			if(resolution < this.resolutions[this.maxZoomLevel]) {
				return this.maxZoomLevel;
			}
			var i:int = this.minZoomLevel + 1;
			var j:int = this.maxZoomLevel
			for (i; i < j; ++i) {
				if ((this.resolutions[i] < resolution) && (Math.abs(this.resolutions[i] - resolution) > RESOLUTION_TOLERANCE)) {
					break;
				}
			}
			return i - 1;
		}

		/**
		 * Return a LonLat which is the passed-in map Pixel, translated into
		 * lon/lat by the layer.
		 */
		public function getLonLatFromMapPx(viewPortPx:Pixel):LonLat {
			var lonlat:LonLat = null;
			if (viewPortPx != null) {
				var size:Size = this.map.size;
				var center:LonLat = this.map.center;
				if (center) {
					var res:Number = this.map.resolution;

					var delta_x:Number = viewPortPx.x - (size.w / 2);
					var delta_y:Number = viewPortPx.y - (size.h / 2);

					lonlat = new LonLat(center.lon + delta_x * res, center.lat - delta_y * res);
				}
			}
			return lonlat;
		}

		/**
		 * Return a Pixel which is the passed-in LonLat,translated into map pixels.
		 */
		public function getMapPxFromLonLat(lonlat:LonLat):Pixel {
			var px:Pixel = null;
			if (lonlat != null) {
				var resolution:Number = this.map.resolution;
				var extent:Bounds = this.map.extent;
				px = new Pixel(Math.round((lonlat.lon - extent.left) / resolution), Math.round((extent.top - lonlat.lat) / resolution));
			}
			return px;
		}

		/**
		 * Clear the layer graphics
		 */
		public function clear():void {
		}

		/**
		 * Reset layer data
		 */
		public function reset():void {
		}

		/**
		 * Reset layer data
		 */
		protected function draw():void {
			Trace.debug("Draw layer");
		}

		public function get displayed():Boolean {
			return this.visible && this.inRange && this.extent;
		}	

		/**
		 * Clear and draw, if needed, layer based on current data eventually retreived previously by moveTo function.
		 * 
		 * @param fullRedraw boolean forece the redraw
		 */
		public function redraw(fullRedraw:Boolean = true):void {
			this.clear();
			if (this.displayed) {
				this.draw();
			}
		}

		public  function get inRange():Boolean {
	    var inRange:Boolean = false;
			if(this.map) {
	    	var resolutionProjected:Number = this.map.resolution;
		    if(this.isBaseLayer != true && this.projection.srsCode != this.map.baseLayer.projection.srsCode)
    		{
		    	resolutionProjected = Proj4as.unit_transform(this.map.baseLayer.projection,this.projection,this.map.resolution);
				}
    		inRange = ((resolutionProjected >= this.minResolution) && (resolutionProjected <= this.maxResolution));
			}
	    	return inRange;
		}

		public function getURL(bounds:Bounds):String {
			return null;
		}

		/**
		 * For layers with a gutter, the image is larger than
		 * the tile by twice the gutter in each dimension.
		 */
		public function get imageSize():Size {
			return this._imageSize;
		}

		public function set imageSize(value:Size):void {
			this._imageSize = value;
		}

		public function get zindex():int {
			return this.parent.getChildIndex(this);
		}

		public function set zindex(value:int):void {
			this.parent.setChildIndex(this, value);
		}

		/**
		 * @return Return the minimum zoom level allowed to display the layer.
		 * The level returned does not take into account the map / baselayer
		 * information, see inRange for that. 
		 */
		public function get minZoomLevel():Number {
			var level:Number = this._minZoomLevel;
			// If the level is not defined explicitely, use the default one
			if (isNaN(level)) {
				// By default the minimum zoom level is the first level
				level = 0;
			}			
			return level;
		}

		/**
		 * Set the minimum zoom level of the layer. There is no link with the
		 * allowed levels of the map depending on its baselayer(s).
		 *
		 * @param value one of the index of the resolutions of the layer
		 */
		public function set minZoomLevel(value:Number):void {
			if ((value >= 0) && (value < this.resolutions.length)) {
				this._minZoomLevel = value;
			} else {
				Trace.error("Layer: invalid minZoomLevel for the layer " + this.name + ": " + value + " is not in [0;" + (this.resolutions.length - 1) + "]");
			}
		}

		/**
		 * @return Return the maximum zoom level allowed to display the layer.
		 * The level returned does not take in account map or baselayer
		 * information, see inRange for that. 
		 */
		public function get maxZoomLevel():Number {
			var level:Number = this._maxZoomLevel;
			// If the level is not defined explicitely, use the default one
			if (isNaN(level)) {
				// By default the maximum zoom level is the last level
				if (this.resolutions) {
					level = this.resolutions.length - 1;
				} else {
					level = 0;
				}
			}
			return level;
		}

		/**
		 * Set the minimum zoom level of the layer. There is no link with the
		 * allowed levels of the map depending on its baselayer(s).
		 *
		 * @param value one of the index of the resolutions of the layer
		 */
		public function set maxZoomLevel(value:Number):void {
			if ((value >= 0) && (value < this.resolutions.length)) {
				this._maxZoomLevel = value;
			} else {
				Trace.error("Layer: invalid maxZoomLevel for the layer " + this.name + ": " + value + " is not in [0;" + (this.resolutions.length - 1) + "]");
			}
		}

		/**
		 * Number of zoom levels
		 */
		public function get numZoomLevels():Number {
			return this.resolutions.length;
		}

		public function get maxResolution():Number {
			var maxRes:Number = NaN;
			if (this.resolutions && (this.resolutions.length > 0)) {
				// By default, the max resolution is used
				maxRes = this.resolutions[0];
				
				if (!isNaN(this._minZoomLevel)) {
					maxRes = this.resolutions[this._minZoomLevel];
				}
			}
			return maxRes;
		}

		public function get minResolution():Number {
			var minRes:Number = NaN;
			if (this.resolutions && (this.resolutions.length > 0)) {
				// By default, the min resolution is used
				minRes = this.resolutions[this.resolutions.length - 1];
				
				if (!isNaN(this._maxZoomLevel)) {
					minRes = this.resolutions[this._maxZoomLevel];
				}
			}
			return minRes;
		}

		/**
		 * The center of these bounds will not stray outside
		 * of the viewport extent during panning.  In addition, if
		 * <displayOutsideMaxExtent> is set to false, data will not be
		 * requested that falls completely outside of these bounds.
		 */
		public function get maxExtent():Bounds {
			return this._maxExtent;
		}

		public function set maxExtent(value:Bounds):void {
			this._maxExtent = value;
		}

		/**
		 * A list of map resolutions (map units per pixel) in descending
		 * order. If this is not set in the layer constructor, it will be set
		 * based on other resolution related properties (maxExtent, maxResolution, etc.).
		 */
		public function get resolutions():Array {
			return this._resolutions;
		}

		public function set resolutions(value:Array):void {
			this._resolutions = value;
			if (this._resolutions == null || this._resolutions.length == 0) {

				this.generateResolutions();
			} else {

				this._autoResolution = false;
			}
			this._resolutions.sort(Array.NUMERIC | Array.DESCENDING);
		}

		/**
		 * Override the default projection. You should also set maxExtent,
		 * maxResolution, and units if appropriate.
		 */
		public function get projection():ProjProjection {
			return this._projection;
		}

		public function set projection(value:ProjProjection):void {
			this._projection = value;

			if (this._autoResolution) {
				this.generateResolutions();
			}
		}

		/**
		 * Whether or not the layer is a base layer. This should be set
		 * individually by all subclasses. Default is false
		 */
		public function get isBaseLayer():Boolean {
			return this._isBaseLayer;
		}

		public function set isBaseLayer(value:Boolean):void {
			this._isBaseLayer = value;
		}

		/**
		 * Whether or not the layer is a fixed layer.
		 * Fixed layers cannot be controlled by users
		 */
		public function get isFixed():Boolean {
			return this._isFixed;
		}

		public function set isFixed(value:Boolean):void {
			this._isFixed = value;
		}

		/**
		 * Proxy (usually a PHP, Python, or Java script) used to request remote servers like
		 * WFS servers in order to allow crossdomain requests. Remote servers can be used without
		 * proxy script by using crossdomain.xml file like http://openscales.org/crossdomain.xml
		 *
		 * There is 3 cases :
		 *  - proxy is explicitly defined
  		 *  - proxy is explicitly defined to "" => no proxy will be used
  		 *  - proxy is null => use the proxy of the map
		 */
		public function get proxy():String {
			if(this._proxy == null && map && map.proxy)
				return map.proxy;
			return this._proxy;
		}

		public function set proxy(value:String):void {
			this._proxy = value;
		}

		public function get security():ISecurity {
			return this._security;
		}

		public function set security(value:ISecurity):void {
			this._security = value;
		}

		public override function set visible(value:Boolean):void {
			super.visible = value;
			if (this.map != null) {
				this.map.dispatchEvent(new LayerEvent(LayerEvent.LAYER_VISIBLE_CHANGED, this));
			}
		}

		/**
		 * Whether or not the layer is loading data
		 */
		public function get loadComplete():Boolean {
			return !this._loading;
		}

		/**
		 * Used to set loading status of layer
		 */
		protected function set loading(value:Boolean):void {
			if (value == true && this._loading == false && this.map != null) {
				_loading = value;
				this.map.dispatchEvent(new LayerEvent(LayerEvent.LAYER_LOAD_START, this));
			}

			if (value == false && this._loading == true && this.map != null) {
				_loading = value;
				this.map.dispatchEvent(new LayerEvent(LayerEvent.LAYER_LOAD_END, this));
			}
		}
	}
}

