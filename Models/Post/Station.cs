using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Post
{
    public class Station
    {
        public int? CompanyId { get; set; }
        public int? MonitoringTypeId { get; set; }
        public string Name { get; set; }
        public bool IsSpcb { get; set; } = false;
        public bool IsCpcb { get; set; } = false;        
        public bool Active { get; set; } = true;

        //public MonitoringType MonitoringType { get; set; }
        //public Company Company { get; set; }  // Navigation property
    }

}
