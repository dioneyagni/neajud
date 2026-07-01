class MoldMatchService
  PREVIEW_WIDTH = 150
  MOLD_SCORE_THRESHOLD = 200_000
  TAMANHO_SCORE_THRESHOLD = 50_000
  DIMENSION_MATCH_THRESHOLD = 0.3

  def self.call(arte)
    new(arte).call
  end

  def initialize(arte)
    @arte = arte
  end

  def call
    arte_preview = @arte.preview_file
    return nil unless arte_preview && File.exist?(arte_preview.to_s)

    arte_outline = generate_outline(arte_preview.to_s)
    return nil unless arte_outline

    begin
      cortes = candidate_cortes
      return nil if cortes.empty?

      best_match(cortes, arte_outline)
    ensure
      File.delete(arte_outline) if arte_outline && File.exist?(arte_outline)
    end
  end

  private

  def candidate_cortes
    if @arte.modelo&.molde
      by_molde = Arquivo.where(organized: true, molde_id: @arte.modelo.molde_id).to_a
      return by_molde if by_molde.any?
    end

    if @arte.client
      molde_ids = Modelo.where(client_id: @arte.client_id).distinct.pluck(:molde_id).compact
      by_client = Arquivo.where(organized: true, molde_id: molde_ids).to_a
      return by_client if by_client.any?
    end

    []
  end

  def best_match(cortes, arte_outline)
    best_tamanho = nil
    best_score = Float::INFINITY

    arte_w_mm = arte_width_mm
    arte_h_mm = arte_height_mm

    cortes.each do |corte|
      next unless corte.preview_file && File.exist?(corte.preview_file.to_s)

      unless dimensions_compatible?(corte, arte_w_mm, arte_h_mm)
        next
      end

      mold_outline = generate_outline(corte.preview_file.to_s)
      next unless mold_outline

      begin
        mold_score = compare_images(arte_outline, mold_outline)
        next unless mold_score && mold_score < MOLD_SCORE_THRESHOLD

        candidate = match_by_dimension(corte)
        candidate ||= match_by_contour(corte, arte_outline)

        next unless candidate
        score = candidate[:score]
        next unless score < best_score

        best_score = score
        best_tamanho = candidate[:tamanho]
      ensure
        File.delete(mold_outline) if mold_outline && File.exist?(mold_outline)
      end
    end

    best_tamanho
  end

  def dimensions_compatible?(corte, arte_w_mm, arte_h_mm)
    return true unless arte_w_mm && arte_h_mm

    corte.tamanhos.any? do |t|
      next false unless t.width_mm && t.height_mm

      t_w = t.width_mm.to_f
      t_h = t.height_mm.to_f
      arte_ratio = arte_h_mm > 0 ? arte_w_mm.to_f / arte_h_mm : 1
      t_ratio = t_h > 0 ? t_w / t_h : 1

      (arte_ratio - t_ratio).abs < 0.5
    end
  end

  def match_by_contour(corte, arte_outline)
    tamanhos = corte.tamanhos.where.not(preview_file: [ nil, "" ])
    return nil if tamanhos.empty?

    best = nil
    best_score = Float::INFINITY

    tamanhos.each do |t|
      t_outline = generate_outline(t.preview_file)
      next unless t_outline

      begin
        score = compare_images(arte_outline, t_outline)
        next unless score && score < TAMANHO_SCORE_THRESHOLD && score < best_score

        best_score = score
        best = t
      ensure
        File.delete(t_outline) if t_outline && File.exist?(t_outline)
      end
    end

    return nil unless best
    { tamanho: best, score: best_score }
  end

  def match_by_dimension(corte)
    arte_w_mm = arte_width_mm
    arte_h_mm = arte_height_mm
    return nil unless arte_w_mm && arte_h_mm

    arte_area = arte_w_mm * arte_h_mm
    arte_ratio = arte_h_mm > 0 ? arte_w_mm.to_f / arte_h_mm : 1

    best = nil
    best_score = Float::INFINITY

    corte.tamanhos.each do |t|
      next unless t.width_mm && t.height_mm

      t_area = t.width_mm * t.height_mm
      t_ratio = t.height_mm > 0 ? t.width_mm.to_f / t.height_mm : 1

      area_diff = arte_area > 0 ? (t_area - arte_area).abs.to_f / arte_area : Float::INFINITY
      ratio_diff = (t_ratio - arte_ratio).abs

      score = area_diff + ratio_diff
      next unless score < best_score

      best_score = score
      best = t
    end

    return nil unless best && best_score < DIMENSION_MATCH_THRESHOLD
    { tamanho: best, score: best_score }
  end

  def arte_width_mm
    return nil unless @arte.width_px && @arte.dpi && @arte.dpi > 0
    @arte.width_px * 25.4 / @arte.dpi.to_f
  end

  def arte_height_mm
    return nil unless @arte.height_px && @arte.dpi && @arte.dpi > 0
    @arte.height_px * 25.4 / @arte.dpi.to_f
  end

  def generate_outline(input_path)
    output = Tempfile.new([ "outline", ".png" ]).path
    system("convert", input_path,
      "-resize", "#{PREVIEW_WIDTH}x>",
      "-colorspace", "Gray",
      "-edge", "1",
      "-negate",
      "-threshold", "50%",
      "-define", "png:color-type=6",
      output)
    return nil unless $?.success? && File.exist?(output)
    output
  end

  def compare_images(img_a, img_b)
    return nil unless File.exist?(img_a) && File.exist?(img_b)

    dims_a = image_dimensions(img_a)
    dims_b = image_dimensions(img_b)
    return nil unless dims_a && dims_b

    if dims_a != dims_b
      resized = Tempfile.new([ "resized", ".png" ]).path
      system("convert", img_a,
        "-resize", "#{dims_b[0]}x#{dims_b[1]}!",
        "-define", "png:color-type=6",
        resized)
      return nil unless $?.success? && File.exist?(resized)

      stderr = `compare -metric AE #{Shellwords.escape(resized)} #{Shellwords.escape(img_b)} null: 2>&1`
      File.delete(resized) if File.exist?(resized)
    else
      stderr = `compare -metric AE #{Shellwords.escape(img_a)} #{Shellwords.escape(img_b)} null: 2>&1`
    end

    return nil unless [ 0, 1 ].include?($?.exitstatus)
    stderr.strip.to_i
  end

  def image_dimensions(path)
    output = `identify -format '%w %h' #{Shellwords.escape(path)} 2>/dev/null`.strip
    return nil if output.blank?
    parts = output.split
    [ parts[0].to_i, parts[1].to_i ]
  end
end
