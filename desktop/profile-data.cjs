module.exports = [
  { id: 'gentle', name: 'Мягкий SNI', detail: 'Одно разбиение, без TTL и OOB', tls: ['-s1+s'] },
  { id: 'multisplit', name: 'SNI Multisplit', detail: 'Несколько TCP-фрагментов', tls: ['-s1', '-s1+s', '-s3+s', '-s6+s'] },
  { id: 'mid-sni', name: 'Середина SNI', detail: 'Не зависит от длины имени сервиса', tls: ['-s1', '-s0+sm'] },
  { id: 'tls-record', name: 'TLS Record', detail: 'TLS-запись в середине SNI · экспериментально', tls: ['-r0+sm', '-s1'] },
  { id: 'record-sni-end', name: 'TLS Record: конец SNI', detail: 'Альтернативная граница TLS-записи · экспериментально', tls: ['-r0+se', '-s1+s'] },
  { id: 'record-sni-start', name: 'TLS Record: начало SNI', detail: 'TLS-запись и TCP-разбиение у начала имени · экспериментально', tls: ['-r1+s', '-s1+s'] },
  { id: 'oob-sni', name: 'OOB SNI', detail: 'Срочные TCP-данные у границы SNI · экспериментально', tls: ['-o1+s', '-s3+s', '-s6+s'] },
  { id: 'disorder-sni', name: 'Disorder SNI', detail: 'Другая последовательность TCP-фрагментов · экспериментально', tls: ['-d1', '-s1+s', '-d3+s', '-s6+s'] }
];
