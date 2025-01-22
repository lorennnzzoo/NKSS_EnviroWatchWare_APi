using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Post.Report
{
    public class ReportFilter
    {
        public int CompanyId { get; set; }
        public List<int> StationsId { get; set; } = new List<int>();
        public List<int> ChannelsId { get; set; } = new List<int>();
        public DataAggregationType DataAggregationType { get; set; }
        public DateTime? From { get; set; }
        public DateTime? To { get; set; }
    }
    public enum DataAggregationType
    {
        Raw = 0,
        FifteenMin = 15,
        OneHour = 60,
        TwelveHours = 720,
        TwentyFourHours = 1440,
        Month = 43200,        
        SixMonths = 259200,   
        Year = 525600         
    }

}
