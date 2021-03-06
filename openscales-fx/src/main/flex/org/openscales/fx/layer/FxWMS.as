package org.openscales.fx.layer
{
	import org.openscales.core.layer.ogc.WMS;
	import org.openscales.core.layer.params.ogc.WMSParams;
	import org.openscales.proj4as.ProjProjection;

	public class FxWMS extends FxGrid
	{
		public function FxWMS() {
			super();
		}

		override public function init():void {
			this._layer = new WMS();
		}

		public function set layers(value:String):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).layers = value;
		}

		public function set styles(value:String):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).styles = value;
		}

		public function set format(value:String):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).format = value;
		}

		override public function set projection(value:String):void {
			super.projection = value;
			if(this.layer != null) {
				((this.layer as WMS).params as WMSParams).srs = value;
			}
		}

		public function set transparent(value:Boolean):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).transparent = value;
		}

		public function set bgcolor(value:String):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).bgcolor = value;
		}

		public function set tiled(value:Boolean):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).tiled = value;
		}

		public function set exceptions(value:String):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).exceptions = value;
		}

		public function set sld(value:String):void {
			if(this.layer != null)
				((this.layer as WMS).params as WMSParams).sld = value;
		}
	}
}
