using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Report
{
    public class ReportData
    {
        public DateTime From { get; set; }
        public DateTime To { get; set; }
        public Company Company { get; set; }
        
        public void CleanChannelLessData()
        {
            Company.Stations = Company.Stations.Where(s => s.Channels.Any()).ToList();
        }
    }

    public class Station
    {
        public string Name { get; set; }
        public List<Channel> Channels { get; set; }
    }

    public class Company
    {
        public string Name { get; set; }
        public string  Address { get; set; }
        public byte[] Logo { get; set; }

        public List<Station> Stations { get; set; }
    }
    public class Channel
    {
        public string Name { get; set; }        
        public string Units { get; set; }
        public List<Data> Data { get; set; }
    }

    public class Data
    {
        public decimal ChannelValue { get; set; }
        public DateTime ChannelDataLogTime { get; set; }
    }
}
