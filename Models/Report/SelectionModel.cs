using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Report.Selection
{
    public class SelectionModel
    {
        public List<Company> Companies { get; set; } = new List<Company>();
        public void CleanUp()
        {
            // Remove companies with no stations
            Companies = Companies.Where(c => c.Stations.Any()).ToList();

            // Remove stations with no channels
            foreach (var company in Companies)
            {
                company.Stations = company.Stations.Where(s => s.Channels.Any()).ToList();
            }
        }
    }

    public class Company
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public List<Station> Stations { get; set; } = new List<Station>();
    }

    public class Station 
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public List<Channel> Channels { get; set; } = new List<Channel>();
    }
    public class Channel 
    {
        public int Id { get; set; }
        public string Name { get; set; }
    }

}
