package org.openscales.core.feature
{
	import flash.display.CapsStyle;
	import flash.display.JointStyle;
	import flash.events.MouseEvent;
	
	import org.openscales.core.Util;
	import org.openscales.core.basetypes.LonLat;
	import org.openscales.core.basetypes.Pixel;
	import org.openscales.core.geometry.Geometry;
	import org.openscales.core.geometry.Point;
	import org.openscales.core.layer.VectorLayer;
	import org.openscales.core.style.Rule;
	import org.openscales.core.style.Style;
	import org.openscales.core.style.symbolizer.Fill;
	import org.openscales.core.style.symbolizer.FillSymbolizer;
	import org.openscales.core.style.symbolizer.Stroke;
	import org.openscales.core.style.symbolizer.StrokeSymbolizer;
	import org.openscales.core.style.symbolizer.Symbolizer;

	/**
	 * Vector features use the Geometry classes as geometry description.
	 * They have an ‘attributes’ property, which is the data object, and a ‘style’ property.
	 */
	public class VectorFeature extends Feature
	{

		private var _geometry:Geometry = null;
		private var _state:String = null;    
		private var _style:Style = null;	    
		private var _originalStyle:Style = null;
		
		
		/**
		 * This Array  is used to record temporaries point for a feature modification
		 * 
		 * there are 2 types or temporaries vertices which represent real vertices and which 
		 * represent a  temporary vertice used to represent the point of the feature  under the mouse
		 **/
		 
		 
		private var _tmpVertices:Array=new Array();
		
		private var _tmpVerticeTolerance:Number=10;
		
		
		
		/**
		 * VectorFeature constructor
		 *
		 * @param geometry The feature's geometry
		 * @param data
		 * @param style The feature's style
		 */
		public function VectorFeature(geom:Geometry = null, data:Object = null, style:Style = null) {
			super(null, null, data);
			this.lonlat = null;
			this.geometry = geom;
			if (this.geometry && this.geometry.id)
				this.name = this.geometry.id;
			this.state = null;
			this.attributes = new Object();
			if (data) {
				this.attributes = Util.extend(this.attributes, data);
			}
			this.style = style ? style : null;
		}

		/**
		 * Destroys the VectorFeature
		 */
		override public function destroy():void {
			if (this.layer) {
				this.layer = null;
			}

			this.geometry = null;
			super.destroy();
		}

		/**
		 * Determines if the feature is placed at the given point with a certain tolerance (or not).
		 *
		 * @param lonlat The given point
		 * @param toleranceLon The longitude tolerance
		 * @param toleranceLat The latitude tolerance
		 */
		public function atPoint(lonlat:LonLat, toleranceLon:Number, toleranceLat:Number):Boolean {
			var atPoint:Boolean = false;
			if(this.geometry) {
				atPoint = this.geometry.atPoint(lonlat, toleranceLon, 
					toleranceLat);
			}
			return atPoint;
		}

		public function get geometry():Geometry {
			return this._geometry;
		}

		public function set geometry(value:Geometry):void {
			this._geometry = value;
		}

		public function get state():String {
			return this._state;
		}

		public function set state(value:String):void {

			if (value == State.UPDATE) {
				switch (this.state) {
					case State.UNKNOWN:
					case State.DELETE:
						this._state = value;
						break;
					case State.UPDATE:
					case State.INSERT:
						break;
				}
			} else if (value == State.INSERT) {
				switch (this.state) {
					case State.UNKNOWN:
						break;
					default:
						this._state = value;
						break;
				}
			} else if (value == State.DELETE) {
				switch (this.state) {
					case State.INSERT:
						break;
					case State.DELETE:
						break;
					case State.UNKNOWN:
					case State.UPDATE:
						this._state = value;
						break;
				}
			} else if (value == State.UNKNOWN) {
				this._state = value;
			}
		}

		public function get style():Style {
			return this._style;
		}

		public function set style(value:Style):void {
			this._style = value;
		}

		public function get originalStyle():Style {
			return this._originalStyle;
		}

		public function set originalStyle(value:Style):void {
			this._originalStyle = value;
		}

		override public function draw():void {
			super.draw();
			
			var style:Style;
			if(this.style == null){
				// FIXME : Ugly thing done here
				style = (this.layer as VectorLayer).style;
			}
			else{
				
				style = this.style;
			}			

			trace("Drawing feature "+this.data["nom_region"]);
			trace("Drawing feature with style : "+style.name);
			var rulesCount:uint = style.rules.length;
			var rule:Rule;
			var symbolizer:Symbolizer;
			var symbolizers:Array;
			var symbolizersCount:uint;
			var j:uint;
			
			for(var i:uint = 0;i<rulesCount;i++){
				
				// TODO : Test if rule applies to the feature
				rule = style.rules[i];
				
				symbolizersCount = rule.symbolizers.length;
				for(j = 0; j<symbolizersCount; j++){
					
					symbolizer = rule.symbolizers[j];
					if(this.acceptSymbolizer(symbolizer)){
						this.setStyle(symbolizer);
						this.executeDrawing(symbolizer);
					}
				}
			}
		}
		
		protected function setStyle(symbolizer:Symbolizer):void{
			
			var symbolizerType:String = typeof(symbolizer);
			if (symbolizer is FillSymbolizer) {
				
				this.configureGraphicsFill((symbolizer as FillSymbolizer).fill);
			}

			if (symbolizer is StrokeSymbolizer) {
				
				this.configureGraphicsStroke((symbolizer as StrokeSymbolizer).stroke);
			}
		}
		
		protected function configureGraphicsFill(fill:Fill):void{
			
			if(fill){
				this.graphics.beginFill(fill.color, fill.opacity);
			} else {
				this.graphics.endFill();
			}
		}
		
		protected function configureGraphicsStroke(stroke:Stroke):void{
			if(stroke){
			var linecap:String;
				var linejoin:String;
				switch(stroke.linecap){
					case Stroke.LINECAP_ROUND:
						linecap = CapsStyle.ROUND;
						break;
					case Stroke.LINECAP_SQUARE:
						linecap = CapsStyle.SQUARE;
						break;
					default:
						linecap = CapsStyle.NONE;
				}
				
				switch(stroke.linejoin){
					case Stroke.LINEJOIN_ROUND:
						linejoin = JointStyle.ROUND;
						break;
					case Stroke.LINEJOIN_BEVEL:
						linejoin = JointStyle.BEVEL;
						break;
					default:
						linejoin = JointStyle.MITER;
				}
				
				this.graphics.lineStyle(stroke.width, stroke.color, stroke.opacity, false, "normal", linecap, linejoin);
			}
			else{
				this.graphics.lineStyle();
			}
		}
		
		protected function acceptSymbolizer(symbolizer:Symbolizer):Boolean{
			
			return true;
		}
		
		protected function executeDrawing(symbolizer:Symbolizer):void{
			trace("Drawing");
		}
		
		protected function getLayerPxFromPoint(point:Point) : Pixel {
			var x:Number = (point.x / this.layer.resolution + this.left);
			var y:Number = (this.top - point.y / this.layer.resolution);
			return this.layer.map.getLayerPxFromMapPx(new Pixel(x, y));
		}
		
		
		
		override protected function verticesShowing(pevt:MouseEvent):void{
			//TODO DAMIEN NDA Remove this condition after testing on all feature
			if((this.layer as VectorLayer).tmpVerticesOnFeature){
			super.verticesShowing(pevt);
			if(this.layer!=null && this.layer.map!=null)
			{
				var px:Pixel=new Pixel(this.layer.mouseX,this.layer.mouseY);
				//tmpPx is used for tolerance
				var tmpPx:Pixel=null;
				var tmpLonLat:LonLat=null;
				var lonlat:LonLat=this.layer.map.getLonLatFromLayerPx(px);
				
				var tmpVerticeUnderTheMouse:PointFeature=this.getTmpFeatureUnderTheMouse();
				//first over
				if(tmpVerticeUnderTheMouse!=null){
					 tmpLonLat=new LonLat((tmpVerticeUnderTheMouse.geometry as Point).x,(tmpVerticeUnderTheMouse.geometry as Point).y);
					 tmpPx=this.layer.map.getLayerPxFromLonLat(tmpLonLat);
				}
				//the point will be add on the LineString to show a vertice which could be modified
			
				
				
				if(tmpPx==null || Math.abs(px.x-tmpPx.x) >tmpVerticeTolerance ||Math.abs(px.y-tmpPx.y)>tmpVerticeTolerance)
				{
				var style:Style = Style.getDefaultCircleStyle();
				//we delete the point under the mouse  from layer and from tmpVertices Array
				(this.layer as VectorLayer).removeFeature(tmpVerticeUnderTheMouse);
				
				Util.removeItem(this.tmpVertices,tmpVerticeUnderTheMouse);
				
				var tmpVertice:PointFeature=new PointFeature(new Point(lonlat.lon,lonlat.lat),{isTmpFeatureUnderTheMouse:true},style,true);
				this.tmpVertices.push(tmpVertice);						
				(this.layer as VectorLayer).addFeature(tmpVertice);
				tmpVertice.unregisterListeners();
				}
			}
			}
		}
		
		override protected function verticesHiding(pevt:MouseEvent):void{
		 	for each(var feature:PointFeature in this.tmpVertices){
		 		(this.layer as VectorLayer).removeFeature(feature);
		 		this.tmpVertices.pop();
		 	}
		 }
		
		
		/**
		 * This function is used to get the temporary pointfeature under the mouse
		 * when the mouse is over the the feature
		 * */
		protected function getTmpFeatureUnderTheMouse():PointFeature{
			for each(var point:PointFeature in this.tmpVertices){
				if(point.attributes.isTmpFeatureUnderTheMouse){
					return point;
				}
			}
			return null;
		}
		
		
		public function get tmpVertices():Array{
			return this._tmpVertices;
		}
		
		public function set tmpVertices(value:Array):void{
			this._tmpVertices=value;
		}
		
		public function get tmpVerticeTolerance():Number{
			return this._tmpVerticeTolerance;	
		}
		public function set tmpVerticeTolerance(tolerance:Number):void{
			this._tmpVerticeTolerance=tolerance;
		}

	}
}

