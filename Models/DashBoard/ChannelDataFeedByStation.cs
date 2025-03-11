using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.DashBoard
{
    public class ChannelDataFeedByStation
    {
        public Station Station { get; set; }
    }
    //public class ChannelDataFeedByCompany
    //{
    //    public Company Company { get; set; }
    //}
    public class ChannelDataFeed
    {
        public int ChannelId { get; set; }
        public string ChannelName { get; set; }

        public string ChannelValue { get; set; }

        public string Units { get; set; }

        public DateTime? ChannelDataLogTime { get; set; }

        public string PcbLimit { get; set; }
        public decimal Average { get; set; }
        public decimal Availability { get; set; }
        public Boolean Active { get; set; }
    }
    public class ChannelData
    {        
        public string ChannelName { get; set; }

        public string ChannelValue { get; set; }

        public string Units { get; set; }

        public DateTime? ChannelDataLogTime { get; set; }

        public string PcbLimit { get; set; }

        public decimal? Minimum { get; set; }

        public decimal? Maximum { get; set; }

        public decimal? Average { get; set; }
    }
    public class Station
    {
        public string Name { get; set; }
        public List<ChannelData> DataFeed { get; set; }
    }

    //public class Company
    //{
    //    public string Name { get; set; }
    //    public List<Station> StationDataFeed { get; set; }
    //}
}
