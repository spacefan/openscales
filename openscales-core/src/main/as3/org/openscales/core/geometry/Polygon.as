package org.openscales.core.geometry
{
	import flash.utils.getQualifiedClassName;
	
	/**
	 * Polygon is a collection of Geometry LinearRings. 
	 */ 
	 
	public class Polygon extends Collection{

    	/**
    	 * An array of class names representing the types of
     	 * components that the collection can include. 
     	 * A null value means the component types are not restricted.
     	 */
    	private var _componentTypes:Array;

    	/**
     	 * Constructor for a Polygon geometry. 
     	 * The first ring (this.component[0])is the outer bounds of the polygon and 
     	 * all subsequent rings (this.component[1-n]) are internal holes.
     	 *
     	 * @param components
     	*/
    	public function Polygon(components:Array=null){
    		this._componentTypes = ["org.openscales.core.geometry::LinearRing"];
    		super(components); 
    	}
    
    	/**
     	 * Calculated by subtracting the areas of the internal holes from the 
     	 *   area of the outer hole.
     	 * 
     	 * @return The area of the geometry
     	 */
   		private function get Area():Number{
        	var area:Number = 0.0;
        	var i:Number, len:Number;
        	if ( this.components && (this.components.length > 0)) {
           		area += Math.abs(this.components[0].getArea());
            	for (i=1, len=this.components.length; i<len; i++) {
                	area -= Math.abs(this.components[i].getArea());
            	}
        	}
       		return area;
    	}

    	/* 
     	* Calculate the approximate area of the polygon were it projected onto
     	*     the earth.
     	*
     	* Params
    	* projection - {<OpenLayers.Projection>} The spatial reference system
     	*     for the geometry coordinates.  If not provided, Geographic/WGS84 is
     	*     assumed.
     	* 
     	* Reference:
     	* Robert. G. Chamberlain and William H. Duquette, "Some Algorithms for
     	*     Polygons on a Sphere", JPL Publication 07-03, Jet Propulsion
     	*     Laboratory, Pasadena, CA, June 2007 http://trs-new.jpl.nasa.gov/dspace/handle/2014/40409
     	*
     	* Returns:
     	* {float} The approximate geodesic area of the polygon in square meters.
     	*/
    	/* getGeodesicArea: function(projection) {
        	var area = 0.0;
        	if(this.components && (this.components.length > 0)) {
            	area += Math.abs(this.components[0].getGeodesicArea(projection));
            	for(var i=1, len=this.components.length; i<len; i++) {
                	area -= Math.abs(this.components[i].getGeodesicArea(projection));
            	}
        	}
        	return area;
    	} */

    	/**
     	* Test if a point is inside a polygon.  Points on a polygon edge are
     	*     considered inside.
     	*
     	*@param point
     	*
     	*@return boolean if the point is inside the polygon.
     	*/
     	public function containsPoint(point:Point):Boolean {
        	var numRings:Number = this.components.length;
        	var contained:Boolean = false;
        	var i:Number;
        	if(numRings > 0) {
           		// check exterior ring - 1 means on edge, boolean otherwise
            	contained = this.components[0].containsPoint(point);
            	if(contained !== 1) {
                	if(contained && numRings > 1) {
                    	// check interior rings
                    	var hole:Boolean;
                    	for(i=1; i<numRings; ++i) {
                        	hole = this.components[i].containsPoint(point);
                        	if(hole) {
                            	if(hole === 1) {
                                	// on edge
                                	contained = false;
                            	} else {
                                	// in hole
                                	contained = false;
                            	}                            
                           		break;
                        	}
                    	}
                	}
            	}
        	}
        	return contained;
    	}

    	/**
     	* Determine if the input geometry intersects this one.
     	*
     	* @param geometry Any type of geometry.
     	*
     	* @return The input geometry intersects this one.
     	*/
    	override public function intersects(geometry:Geometry):Boolean{
        	var intersect:Boolean = false;
        	var i:Number, len:Number;
       		if(geometry is Point) {
            	intersect = this.containsPoint(geometry as Point);
        	} 
        	else if(geometry is LineString || geometry is LinearRing) {
            	// check if rings/linestrings intersect
            	 for(i=0, len=this.components.length; i<len; ++i) {
                	intersect = (geometry as LineString).intersects(this.components[i]);
                	if(intersect) {
                    	break;
                	} 
            	}
            	if(!intersect) {
               	// check if this poly contains points of the ring/linestring
                	for(i=0, len=(geometry as LineString).components.length; i<len; ++i) {
                    	intersect = this.containsPoint((geometry as Curve).components[i]);
                    	if(intersect) {
                        	break;
                    	}
                	}
            	}
        	} 
        	else {
            	for(i=0, len=(geometry as Collection).components.length; i<len; ++ i) {
                	intersect = this.intersects((geometry as Collection).components[i]);
                	if(intersect) {break;}
            	}
        	}
        	// check case where this poly is wholly contained by another
        	if(!intersect && getQualifiedClassName(geometry) == "org.openscales.core.geometry::Polygon") {
            	// exterior ring points will be contained in the other geometry
           	var ring:LinearRing = this.components[0];
            	for(i=0, len=ring.components.length; i<len; ++i) {
                	intersect = (geometry as Polygon).containsPoint(ring.components[i]);
                	if(intersect) {
                    	break;
                	}
            	}
        	}
        	return intersect;
    	}

    	/*
     	* Calculate the closest distance between two geometries (on the x-y plane).
     	*
     	* Parameters:
     	* @geometry:Geometry - The target geometry.
     	* @options:Object - Optional properties for configuring the distance
     	*     calculation.
     	*
     	* Valid options:
     	* details - {Boolean} Return details from the distance calculation.
     	*     Default is false.
     	* edge - {Boolean} Calculate the distance from this geometry to the
     	*     nearest edge of the target geometry.  Default is true.  If true,
     	*     calling distanceTo from a geometry that is wholly contained within
     	*     the target will result in a non-zero distance.  If false, whenever
     	*     geometries intersect, calling distanceTo will return 0.  If false,
     	*     details cannot be returned.
     	*
     	* Returns:
     	* {Number | Object} The distance between this geometry and the target.
     	*     If details is true, the return will be an object with distance,
     	*     x0, y0, x1, and y1 properties.  The x0 and y0 properties represent
     	*     the coordinates of the closest point on this geometry. The x1 and y1
     	*     properties represent the coordinates of the closest point on the
     	*     target geometry.
     	*/
    	// TODO : backport from OpenLayers not finish
    	
    	/* private function distanceTo(geometry:Geometry, options:Object) {
        	var edge = !(options && options.edge === false); // === compare value and type
        	var result;
        	// this is the case where we might not be looking for distance to edge
        	if(!edge && this.intersects(geometry)) {
           		result = 0;
        	}
        	else{result = OpenLayers.Geometry.Collection.prototype.distanceTo.apply(this, [geometry, options]);
        	}
        	return result;
    	} */
	

		/**
 		* Create a regular polygon around a radius. Useful for creating circles 
 		* and the like.
 		*
 		* @param origin The center of polygon.
 		* @param radius Distance to vertex, in map units.
 		* @param sides Number of sides. 20 approximates a circle.
 		* @param rotation original angle of rotation, in degrees.
 		*/
		 public function createRegularPolygon(origin:Point, radius:Number, sides:Number, rotation:Number):Polygon {  
    		var angle:Number = Math.PI * ((1/sides) - (1/2));
    		if(rotation) {
        		angle += (rotation / 180) * Math.PI;
    		}
    		var rotatedAngle:Number, x:Number, y:Number;
    		var points:Array = [];
    		for(var i:Number=0; i<sides; ++i) {
        		rotatedAngle = angle + (i * 2 * Math.PI / sides);
        		x = origin.x + (radius * Math.cos(rotatedAngle));
        		y = origin.y + (radius * Math.sin(rotatedAngle));
        		points.push(new Point(x, y));
    		}
    		var ring:LinearRing = new LinearRing(points);
    		return new Polygon([ring]);
		} 
	}
}