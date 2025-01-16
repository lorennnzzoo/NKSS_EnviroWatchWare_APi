using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models
{
    public class Station
    {
        public int? Id { get; set; }
        public int? CompanyId { get; set; }
        public int? MonitoringTypeId { get; set; }
        public string Name { get; set; }
        public bool IsSpcb { get; set; } 
        public bool IsCpcb { get; set; } 
        public bool Active { get; set; }

        public DateTime CreatedOn { get; set; }
        //public MonitoringType MonitoringType { get; set; }
        //public Company Company { get; set; }  // Navigation property
    }

}
