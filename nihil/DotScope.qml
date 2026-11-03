import QtQuick
import "." as N

// Logarithmic LED-matrix oscilloscope for network rx/tx time series.
Canvas {
  id: root

  property var series: []
  property var secondary: []
  property int samples: 44
  property real floor: 512

  implicitHeight: 52

  // Canvas does not track colours: repaint when the palette changes.
  readonly property color unlitColor: N.Palette.unlit
  readonly property color primaryColor: N.Palette.lit
  readonly property color secondaryColor: N.Palette.muted
  onUnlitColorChanged: requestPaint()
  onPrimaryColorChanged: requestPaint()
  onSecondaryColorChanged: requestPaint()

  onSeriesChanged: requestPaint()
  onSecondaryChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function level(v, peak) {
    if (v <= root.floor) return 0
    return Math.min(1, Math.log(v / root.floor) / Math.log(Math.max(peak, root.floor * 4) / root.floor))
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    if (width <= 0 || height <= 0) return

    var step = width / Math.max(1, samples)
    var rows = Math.max(3, Math.floor(height / step))
    var r = Math.max(1.1, step * 0.28)
    var peak = root.floor * 4
    var idx
    for (idx = 0; idx < series.length; idx++) if (series[idx] > peak) peak = series[idx]
    for (idx = 0; idx < secondary.length; idx++) if (secondary[idx] > peak) peak = secondary[idx]

    ctx.fillStyle = root.unlitColor
    for (var i = 0; i < samples; i++) {
      for (var j = 0; j < rows; j++) {
        ctx.beginPath()
        ctx.arc(i * step + step / 2, height - j * step - step / 2, r * 0.6, 0, 2 * Math.PI)
        ctx.fill()
      }
    }

    function drawTrace(data, col) {
      if (!data || data.length === 0) return
      ctx.fillStyle = col
      var slice = data.length > root.samples ? data.slice(data.length - root.samples) : data
      var offset = root.samples - slice.length
      for (var k = 0; k < slice.length; k++) {
        var h = Math.round(root.level(slice[k], peak) * (rows - 1))
        if (h <= 0 && slice[k] <= root.floor) continue
        ctx.beginPath()
        ctx.arc((offset + k) * step + step / 2, height - h * step - step / 2, r, 0, 2 * Math.PI)
        ctx.fill()
      }
    }

    drawTrace(root.secondary, root.secondaryColor)
    drawTrace(root.series, root.primaryColor)
  }
}
