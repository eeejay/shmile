im = require("imagemagick")
exec = require("child_process").exec
fs = require("fs")
EventEmitter = require("events").EventEmitter

IMAGE_HEIGHT = 800
IMAGE_WIDTH = 1200
IMAGE_PADDING = 50
TOTAL_HEIGHT = IMAGE_HEIGHT * 2 + IMAGE_PADDING * 3
TOTAL_WIDTH = IMAGE_WIDTH * 2 + IMAGE_PADDING * 3

# Composites an array of four images into the final grid-based image asset.
class ImageCompositor
  defaults:
    overlay_src: "public/images/overlay.png"
    strips_overlay_src: "public/images/strips_overlay.png"
    tmp_dir: "public/temp"
    output_dir: "public/photos/generated"
    thumb_dir: "public/photos/generated/thumbs"

  constructor: (@img_src_list=[], @opts=null, @cb, @printstrips=false) ->
    console.log("img_src_list is: #{@img_src_list}")
    @opts = @defaults if @opts is null

  init: ->
    emitter = new EventEmitter()
    emitter.on "composite", =>
      convertArgs = [ "-size", TOTAL_WIDTH + "x" + TOTAL_HEIGHT, "canvas:white" ]
      utcSeconds = (new Date()).valueOf()
      IMAGE_GEOMETRY = "#{IMAGE_WIDTH}x#{IMAGE_HEIGHT}"
      OUTPUT_PATH = "#{@opts.tmp_dir}/out.jpg"
      OUTPUT_FILE_NAME = "#{utcSeconds}.jpg"
      FINAL_OUTPUT_PATH = "#{@opts.output_dir}/gen_#{OUTPUT_FILE_NAME}"
      FINAL_OUTPUT_STRIPS_PATH = "#{@opts.output_dir}/strips_#{OUTPUT_FILE_NAME}"
      FINAL_OUTPUT_THUMB_PATH = "#{@opts.thumb_dir}/thumb_#{OUTPUT_FILE_NAME}"
      GEOMETRIES = [ IMAGE_GEOMETRY + "+" + IMAGE_PADDING + "+" + IMAGE_PADDING, IMAGE_GEOMETRY + "+" + (2 * IMAGE_PADDING + IMAGE_WIDTH) + "+" + IMAGE_PADDING, IMAGE_GEOMETRY + "+" + IMAGE_PADDING + "+" + (IMAGE_HEIGHT + 2 * IMAGE_PADDING), IMAGE_GEOMETRY + "+" + (2 * IMAGE_PADDING + IMAGE_WIDTH) + "+" + (2 * IMAGE_PADDING + IMAGE_HEIGHT) ]

      for i in [0..@img_src_list.length-1] by 1
        convertArgs.push @img_src_list[i]
        convertArgs.push "-geometry"
        convertArgs.push GEOMETRIES[i]
        convertArgs.push "-composite"
      convertArgs.push OUTPUT_PATH

      console.log("executing: convert #{convertArgs.join(" ")}")

      im.convert(
        convertArgs,
        (err, stdout, stderr) =>
          throw err  if err
          emitter.emit "laid_out", OUTPUT_PATH
          doStrips() if @printstrips
          doCompositing()
      )

      doStrips = =>
        stripsArgs = [ "-size", "1200x1800", "canvas:white" ]
        STRIP_SINGLE_WIDTH = 580
        STRIP_SINGLE_HEIGHT = 387
        GRAVITIES = ["NorthWest", "SouthWest", "NorthEast", "SouthEast"]
        GEOMS = [STRIP_SINGLE_WIDTH + "x+0+0", STRIP_SINGLE_WIDTH + "x+0+" + (STRIP_SINGLE_HEIGHT + 50)]

        for i in [0..@img_src_list.length-1] by 1
          stripsArgs.push @img_src_list[i]
          stripsArgs.push "-gravity"
          stripsArgs.push GRAVITIES[Math.floor i/2]
          stripsArgs.push "-geometry"
          stripsArgs.push GEOMS[if i == 1 or i == 2 then 1 else 0]
          stripsArgs.push "-composite"

          stripsArgs.push @img_src_list[i]
          stripsArgs.push "-gravity"
          stripsArgs.push GRAVITIES[Math.floor (i + 4)/2]
          stripsArgs.push "-geometry"
          stripsArgs.push GEOMS[if i == 1 or i == 2 then 1 else 0]
          stripsArgs.push "-composite"

        stripsArgs.push @opts.strips_overlay_src
        stripsArgs.push "-gravity"
        stripsArgs.push "Center"
        stripsArgs.push "-composite"
        stripsArgs.push "-rotate"
        stripsArgs.push "90"
        stripsArgs.push FINAL_OUTPUT_STRIPS_PATH

        console.log("executing: convert #{stripsArgs.join(" ")}")

        im.convert(
          stripsArgs,
          (err, stdout, stderr) ->
            throw err  if err
            emitter.emit "composited_strips", FINAL_OUTPUT_STRIPS_PATH
        )

      doCompositing = =>
        compositeArgs = [ "-gravity", "center", @opts.overlay_src, OUTPUT_PATH, "-geometry", TOTAL_WIDTH + "x" + TOTAL_HEIGHT, FINAL_OUTPUT_PATH ]
        console.log("executing: composite " + compositeArgs.join(" "))
        exec "composite " + compositeArgs.join(" "), (error, stderr, stdout) ->
          throw error  if error
          emitter.emit "composited", FINAL_OUTPUT_PATH
          doGenerateThumb()

      resizeCompressArgs = [ "-size", "25%", "-quality", "20", FINAL_OUTPUT_PATH, FINAL_OUTPUT_THUMB_PATH ]
      doGenerateThumb = =>
        im.convert resizeCompressArgs, (e, out, err) ->
          throw err  if err
          emitter.emit "generated_thumb", FINAL_OUTPUT_THUMB_PATH

    emitter

module.exports = ImageCompositor
