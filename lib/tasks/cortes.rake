# Painel 2/4a2 (decided 06/11/2026): measure by layer the cortes detected
# before the Corte's time needed it. Writes only tamanhos.linhas_por_cor;
# on the development database, take a bin/dev-backup first.
namespace :cortes do
  desc "Fill each corte size's lines by layer color (MedirCamadasDoCorte)"
  task medir_camadas: :environment do
    cortes = Arquivo.where(category: "corte").where("LOWER(extension) = 'dxf'").where(id: Tamanho.where(linhas_por_cor: nil).select(:arquivo_id))
    cortes.find_each do |corte|
      resultado = MedirCamadasDoCorte.call(corte)
      puts "#{corte.uuid} #{corte.filename}: #{resultado.medidos} measured, #{resultado.sem_deteccao} not found"
    end
  end
end
