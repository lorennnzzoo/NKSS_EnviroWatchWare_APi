using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models
{
    public class ServiceLogs
    {
        public int LogId { get; set; }
        public string LogType { get; set; }
        public string Message { get; set; }
        public string SoftwareType { get; set; }
        public string Class { get; set; }
        public DateTime LogTimestamp { get; set; }
    }
}
