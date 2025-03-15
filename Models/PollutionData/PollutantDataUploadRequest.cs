using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PollutionData
{
    public class PollutantDataUploadRequest
    {
        public List<Station> Stations { get; set; }
    }

    public class Station
    {
        public int? StationId { get; set; }  
        public string StationName { get; set; } 
        public List<Channel> Channels { get; set; }
    }

    public class Channel
    {
        public int? ChannelId { get; set; }  
        public string ChannelName { get; set; }  
        public string LoggingUnits { get; set; } 
        public decimal? Value { get; set; }  
        public DateTime? LogTime { get; set; } 
    }


    public class ConfigFilter
    {
        public int CompanyId { get; set; }
        public List<int> StationsId { get; set; } = new List<int>();
        public List<int> ChannelsId { get; set; } = new List<int>();
    }


    public class Config
    {
        public List<StationConfig> Stations { get; set; }
    }

    public class StationConfig
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public List<ChannelConfig> Channels { get; set; }
    }

    public class ChannelConfig
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string LoggingUnits { get; set; }
    }


}
