package org.openscales.fx.layer
{
	import org.openscales.basetypes.LonLat;
	import org.openscales.core.layer.TMS;
	
	public class FxTMS extends FxGrid
	{
		public function FxTMS()
		{
			super();
			if(this._layer == null)
				this._layer = new TMS("","");
		}
		public function set format(value:String):void {
			if(this.layer != null)
				(this.layer as TMS).format = value;
		}
		public function set origin(value:String):void {
			if(this.layer != null) {
				(this.layer as TMS).origin = LonLat.getLonLatFromString(value);
			}
		}
	}
}