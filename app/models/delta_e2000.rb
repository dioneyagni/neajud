# The CIEDE2000 color difference between two CIE Lab colors (Etapa 2.5b):
# how far apart two cores lisas look — about 1 is the least a trained eye
# notices side by side. Pure Ruby, after Sharma, Wu & Dalal (2005), whose
# test pairs the spec checks.
#
# Usage: DeltaE2000.entre([50.0, 2.6772, -79.7751], [50.0, 0.0, -82.7485]) # => 2.0425
module DeltaE2000
  module_function

  def entre(lab1, lab2)
    l1, a1, b1 = lab1.map(&:to_f)
    l2, a2, b2 = lab2.map(&:to_f)
    c_media = (Math.hypot(a1, b1) + Math.hypot(a2, b2)) / 2
    g = 0.5 * (1 - Math.sqrt(c_media**7 / (c_media**7 + 25.0**7)))
    c1, h1 = croma_e_matiz(a1 * (1 + g), b1)
    c2, h2 = croma_e_matiz(a2 * (1 + g), b2)
    termos(l2 - l1, c2 - c1, delta_h(c1, c2, h1, h2), (l1 + l2) / 2, (c1 + c2) / 2, h_media(c1, c2, h1, h2))
  end

  def croma_e_matiz(a, b)
    [ Math.hypot(a, b), (a.zero? && b.zero?) ? 0.0 : Math.atan2(b, a) * 180 / Math::PI % 360 ]
  end

  def delta_h(c1, c2, h1, h2)
    return 0.0 if (c1 * c2).zero?

    dh = h2 - h1
    dh -= 360 if dh > 180
    dh += 360 if dh < -180
    2 * Math.sqrt(c1 * c2) * Math.sin(radianos(dh / 2))
  end

  def h_media(c1, c2, h1, h2)
    return h1 + h2 if (c1 * c2).zero?
    return (h1 + h2) / 2 if (h1 - h2).abs <= 180

    (h1 + h2 < 360 ? h1 + h2 + 360 : h1 + h2 - 360) / 2
  end

  # The weighted sum, with the rotation term for blues.
  def termos(dl, dc, dh, l_media, c_media, h_media)
    t = 1 - 0.17 * Math.cos(radianos(h_media - 30)) + 0.24 * Math.cos(radianos(2 * h_media)) +
        0.32 * Math.cos(radianos(3 * h_media + 6)) - 0.20 * Math.cos(radianos(4 * h_media - 63))
    sl = 1 + 0.015 * (l_media - 50)**2 / Math.sqrt(20 + (l_media - 50)**2)
    sc = 1 + 0.045 * c_media
    sh = 1 + 0.015 * c_media * t
    rt = -2 * Math.sqrt(c_media**7 / (c_media**7 + 25.0**7)) * Math.sin(radianos(60 * Math.exp(-(((h_media - 275) / 25)**2))))
    Math.sqrt((dl / sl)**2 + (dc / sc)**2 + (dh / sh)**2 + rt * (dc / sc) * (dh / sh))
  end

  def radianos(graus)
    graus * Math::PI / 180
  end
end
