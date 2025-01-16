using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models
{
    public class MonitoringType
    {
        public int? Id { get; set; }
        public string MonitoringTypeName { get; set; }
        public bool Active { get; set; } 
    }
}
