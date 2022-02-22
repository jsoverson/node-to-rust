class Prawn::SVG::TTF
  SFNT_VERSION_STRINGS = ["\x00\x01\x00\x00", "true", "typ1"]
  LANGUAGE_IDS = [0, 0x409] # English, US English
  UTF_16BE_PLATFORM_IDS = [0, 3] # Unicode, Microsoft

  attr_reader :family, :subfamily

  def initialize(filename)
    load_data_from_file(filename)
  end

  private

  def load_data_from_file(filename)
    File.open(filename, "rb") do |f|
      offset_table = f.read(12)
      return unless offset_table && offset_table.length == 12 && SFNT_VERSION_STRINGS.include?(offset_table[0..3])

      table_count = offset_table[4].ord * 256 + offset_table[5].ord
      tables = f.read(table_count * 16)
      return unless tables && tables.length == table_count * 16

      offset, length = table_count.times do |index|
        start = index * 16
        if tables[start..start+3] == 'name'
          break tables[start+8..start+15].unpack("NNN")
        end
      end

      return unless length
      f.seek(offset)
      data = f.read(length)
      return unless data && data.length == length

      format, name_count, string_offset = data[0..5].unpack("nnn")

      names = {}
      name_count.times do |index|
        start = 6 + index * 12
        platform_id, platform_specific_id, language_id, name_id, length, offset = data[start..start+11].unpack("nnnnnn")
        next unless offset
        next unless LANGUAGE_IDS.include?(language_id)
        next unless [1, 2, 16, 17].include?(name_id)

        offset += string_offset
        field = data[offset..offset+length-1]
        next unless field && field.length == length

        names[name_id] = if UTF_16BE_PLATFORM_IDS.include?(platform_id)
          field.force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8) rescue field
        else
          field
        end
      end

      @family = names[16] || names[1]
      @subfamily = names[17] || names[2]
    end
  rescue Errno::ENOENT # in case the file disappears between the scan and the load, we don't want to crash
  end
end
