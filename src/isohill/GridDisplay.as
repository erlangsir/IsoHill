/* IsoHill engine, http://www.isohill.com
* Copyright (c) 2011, Jonathan Dunlap, http://www.jadbox.com
* All rights reserved. Licensed: http://www.opensource.org/licenses/bsd-license.php
* 
* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
* 
* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
*/
package isohill 
{
	import flash.utils.Dictionary;
	import isohill.plugins.IPlugin;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.Sprite;
	/**
	 * Unbounded two directional vector (using single vector math)
	 * @author Jonathan Dunlap
	 */
	public class GridDisplay implements IPlugin
	{
		public var name:String;
		private var data:Vector.<Vector.<IsoDisplay>>;
		private var flatData:Vector.<IsoDisplay>;
		private var w:int = 0;
		private var h:int = 0;
		private var tileWidth:int = 1;
		private var tileHeight:int = 1;
		public var sort:Boolean = true;
		public var container:Sprite;
		public var spriteHash:Dictionary = new Dictionary(true); // sprite name -> IsoDisplay
		
		public function GridDisplay(name:String, w:int, h:int, cellwidth:int, cellheight:int) 
		{
			this.name = name;
			this.w = w;
			this.h = h;
			this.tileWidth = cellwidth;
			this.tileHeight = cellheight;
			container = new Sprite();
			data = new Vector.<Vector.<IsoDisplay>>(w * h + 1, true);
			flatData = new <IsoDisplay>[];
		}
		public function toString():String {
			var result:String = "";
			for (var y:int = 0; y < h; y++) {
				for (var x:int = 0; x < w; x++) {
					result += getCell(x, y).toString();
				}
				result += "\n";
			}	
			return result; 
		}
		public function flatten():void {
			sort = false;
			container.flatten();
		}
		public function unflatten():void {
			sort = true;
			container.unflatten();
		}
		public function isFlattened():Boolean {
			return container.isFlattened;
		}
		// get the collection of IsoDisplays in cell location
		public function getCell(x:int, y:int):Vector.<IsoDisplay> {
			if (x > w) x = w-1; // inlined bound checking for speed
			else if (x < 1) x = 1;
			if (y > h) y = h - 1;
			else if (y < 1) y = 1;
			
			var index:int = (y*w)+x;
			return data[index];
		}
		// grid location to iso layer location
		public function toLayerPt(x:int, y:int, z:int = 1):Point3 {
			x++; y++;
			return new Point3(x * (tileHeight - 1), y * (tileHeight - 1), z);
		}
		// layer pt to grid location
		public function fromLayerPt(x:Number, y:Number, z:Number=1):Point3 {
			return new Point3(x / (tileHeight - 1)+1, y / (tileHeight - 1)+1, z);
		}
		private function updateLocation(val:IsoDisplay):void {
			var x:int = Math.floor(val.pt.x / tileHeight);
			var y:int = Math.floor(val.pt.y / tileHeight);
			if (x >= w) x = w-1; // inlined bound checking for speed
			else if (x < 1) x = 1;
			if (y >= h) y = h - 1;
			else if (y < 1) y = 1;
			
			var index:int = (y * w) + x;
			if (index == val.layerIndex) return; // no change needed
			//trace(x, y);
			removeFromGridData(val);
			
			var collection:Vector.<IsoDisplay> = data[index];
			if (collection == null) collection = data[index] = new Vector.<IsoDisplay>();
			collection.push(val);
			val.layerIndex = index;
		}
		private function removeFromGridData(val:IsoDisplay):void {
			if (val.layerIndex == -1) return;
			var arr:Vector.<IsoDisplay> = data[val.layerIndex];
			if (arr == null) { val.layerIndex = -1; return;}
			//throw new Error("invalid layer index " + val.layerIndex);
			var index:int = arr.indexOf(val);
			if (index == -1) { trace("Sprite '" + val.name + "' not found on array layer: " + name + ",  hash has:"+spriteHash[val.name]); return; }
			arr.splice(index, 1);
			val.layerIndex = -1;
		}
		public function push(val:IsoDisplay):IsoDisplay {
			if (val == null) return val;
			if (val.name == "" || val.name == null) {
				throw new Error("adding sprite with no name");
			}

			updateLocation(val);
			spriteHash[val.name] = val;
			val.layer = this;
			addStarlingChild(val.display);
			return val;
		}
		public function remove(val:IsoDisplay):IsoDisplay {
			if (val.layerIndex == -1 || val.layer==null) return val;
			container.removeChild(val.display);
			
			removeFromGridData(val);
			val.layer = null;
			delete spriteHash[val.name];
			return val;
		}
		public function get numChildren():int {
			return container.numChildren;
		}
		public function setCell(val:Vector.<IsoDisplay>):Vector.<IsoDisplay> {
			for each (var sprite:IsoDisplay in val) push(sprite);
			return val;
		}
		private function addStarlingChild(image:DisplayObject):void {
			var wasFlat:Boolean = container.isFlattened;
			if(wasFlat) container.unflatten();
			container.addChild(image);
			if (container.isFlattened) {
				sortSystem();
				container.flatten();
			}
		}
		public function advanceTime(time:Number, engine:IsoHill):void {
			var first:IsoDisplay;
			for each(var layer:Vector.<IsoDisplay> in data) {
				if (layer != null) for each(var sprite:IsoDisplay in layer) {
					if (sprite == null) continue;
					updateLocation(sprite);
					sprite.advanceTime(time);
				}
			}
			
			if (sort) sortSystem();
		}
		private function sortSystem():void {
			var f:DisplayObject;
			var numSprites:int = container.numChildren;
			var c:DisplayObject;
			for (var i:int = 0; i < numSprites; i++) {
				c = container.getChildAt(i);
				if (f != null && sorterDisplay(f, c)) container.swapChildren(f, c);
				f = c;
			}
		}
		// Compare two entities and return true if they need to be depth swapped
		/*
		private function sorter(f:IsoDisplay, s:IsoDisplay):Boolean {
			var key:Number = f.display.y + f.display.height; //f.pt.x + f.pt.y + f.display.height;
			var key2:Number = s.display.y + s.display.height; //s.pt.x + s.pt.y + s.display.height-.1;
			return key > key2;
		}*/
		private function sorterDisplay(f:DisplayObject, s:DisplayObject):Boolean {
			var key:Number = f.y;
			var key2:Number = s.y;
			return key > key2;
		}
	}

}