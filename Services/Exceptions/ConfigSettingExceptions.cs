using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    class CannotCreateMultipleContentsWithSameNameInSameGroup:Exception
    {
        public CannotCreateMultipleContentsWithSameNameInSameGroup(string contentName,string groupName) : base($"Cannot Create Another Content Name : {contentName} In Group : {groupName}")
        {

        }
    }
}
