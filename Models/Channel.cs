using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models
{
    public class Channel
    {
        public int? Id { get; set; }
        public int? StationId { get; set; }
        public string Name { get; set; }
        public string LoggingUnits { get; set; }
        public int? ProtocolId { get; set; }       
        public bool Active { get; set; } 
        public int? ValuePosition { get; set; }
        public decimal? MaximumRange { get; set; }
        public decimal? MinimumRange { get; set; }
        public decimal? Threshold { get; set; }
        public string CpcbChannelName { get; set; }
        public string SpcbChannelName { get; set; }
        public int? OxideId { get; set; }
        public int? Priority { get; set; }       
        public bool IsCpcb { get; set; }
        public bool IsSpcb { get; set; }     
        public int? ScalingFactorId { get; set; }
        public string OutputType { get; set; }
        public int? ChannelTypeId { get; set; }
        public decimal? ConversionFactor { get; set; }
        public DateTime CreatedOn { get; set; }
        //public Analyzer Analyzer { get; set; }  // Navigation property
        //public Oxide Oxide { get; set; }  // Navigation property
        //public Station Station { get; set; }  // Navigation property
    }

}
