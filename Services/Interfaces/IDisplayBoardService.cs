using Models.DisplayBoard;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IDisplayBoardService
    {
        void CreateTemplate(Template template);
        IEnumerable<Template> GetAllTemplates();
        Template GetTemplate(string id);
        void UpdateTemplate(Template template);
        void DeleteTemplate(string id);
    }
}
