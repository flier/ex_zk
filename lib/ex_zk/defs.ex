defmodule ExZk.Defs do
  import ExZk.TypedEnum

  defenum(OpCode,
    notification: 0,
    create: 1,
    delete: 2,
    exists: 3,
    getData: 4,
    setData: 5,
    getACL: 6,
    setACL: 7,
    getChildren: 8,
    sync: 9,
    ping: 11,
    getChildren2: 12,
    check: 13,
    multi: 14,
    create2: 15,
    reconfig: 16,
    checkWatches: 17,
    removeWatches: 18,
    createContainer: 19,
    deleteContainer: 20,
    createTTL: 21,
    multiRead: 22,
    auth: 100,
    setWatches: 101,
    sasl: 102,
    getEphemerals: 103,
    getAllChildrenNumber: 104,
    setWatches2: 105,
    addWatch: 106,
    whoAmI: 107,
    createSession: -10,
    closeSession: -11,
    error: -1
  )

  defenum(Perms,
    read: 1,
    write: 2,
    create: 4,
    delete: 8,
    admin: 16,
    all: 31
  )
end
